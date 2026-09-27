classdef ExcavatorFourSensorReaderLive < matlab.System
    %EXCAVATORFOURSENSORREADERLIVE Robust nonblocking four-sensor receiver.
    %
    % Output vector (12x1):
    % 1 A0_q_m, 2 A1_q_m, 3 A2_q_m, 4 rotation_raw,
    % 5 rotation_angle_deg, 6 status, 7 valid_frames,
    % 8 invalid_frames, 9 seconds_since_valid_frame,
    % 10 A0_raw, 11 A1_raw, 12 A2_raw.
    %
    % Status: 0=no serial port, 1=port open/waiting for a valid frame,
    %         2=valid frames streaming, 3=data stale (>0.5 s old).

    properties (Nontunable)
        COMPort (1,1) string = "auto"
        BaudRate (1,1) double = 115200
        SampleTime (1,1) double = 0.02
        ReconnectPeriod (1,1) double = 1.0
        StaleTimeout (1,1) double = 0.5
    end

    properties (Access = private)
        SerialDevice
        RxBuffer = uint8([])
        SensorData (5,1) double = [0; 0; 0; 0; 0]
        CylinderRaw (3,1) double = [0; 0; 0]
        Status (1,1) double = 0
        ValidFrames (1,1) double = 0
        InvalidFrames (1,1) double = 0
        AgeSeconds (1,1) double = inf
        ReconnectTicks (1,1) double = 0
    end

    methods (Access = protected)
        function setupImpl(obj)
            obj.SensorData = [0; 0; 0; 0; 0];
            obj.CylinderRaw = [0; 0; 0];
            obj.Status = 0;
            obj.ValidFrames = 0;
            obj.InvalidFrames = 0;
            obj.AgeSeconds = inf;
            obj.ReconnectTicks = 0;
            obj.RxBuffer = uint8([]);
            obj.connectSerial();
        end

        function data = stepImpl(obj)
            if isfinite(obj.AgeSeconds)
                obj.AgeSeconds = obj.AgeSeconds + obj.SampleTime;
            end

            if isempty(obj.SerialDevice)
                obj.Status = 0;
                obj.ReconnectTicks = obj.ReconnectTicks - 1;
                if obj.ReconnectTicks <= 0
                    obj.connectSerial();
                end
            else
                try
                    byteCount = obj.SerialDevice.NumBytesAvailable;
                    if byteCount > 0
                        newBytes = read(obj.SerialDevice, byteCount, 'uint8');
                        obj.RxBuffer = [obj.RxBuffer reshape(uint8(newBytes), 1, [])]; %#ok<AGROW>
                        obj.consumeCompleteLines();
                    end

                    if obj.ValidFrames == 0
                        obj.Status = 1;
                    elseif obj.AgeSeconds <= obj.StaleTimeout
                        obj.Status = 2;
                    else
                        obj.Status = 3;
                    end
                catch
                    obj.disconnectSerial();
                    obj.scheduleReconnect();
                end
            end

            data = [obj.SensorData; obj.Status; obj.ValidFrames; ...
                obj.InvalidFrames; obj.AgeSeconds; obj.CylinderRaw];
        end

        function resetImpl(obj)
            obj.SensorData = [0; 0; 0; 0; 0];
            obj.CylinderRaw = [0; 0; 0];
            obj.ValidFrames = 0;
            obj.InvalidFrames = 0;
            obj.AgeSeconds = inf;
            obj.RxBuffer = uint8([]);
            if ~isempty(obj.SerialDevice)
                try
                    flush(obj.SerialDevice);
                    obj.Status = 1;
                catch
                    obj.disconnectSerial();
                end
            end
        end

        function releaseImpl(obj)
            obj.disconnectSerial();
        end

        function sampleTime = getSampleTimeImpl(obj)
            sampleTime = createSampleTime(obj, ...
                'Type', 'Discrete', 'SampleTime', obj.SampleTime);
        end

        function sizeOut = getOutputSizeImpl(~)
            sizeOut = [12 1];
        end

        function typeOut = getOutputDataTypeImpl(~)
            typeOut = 'double';
        end

        function complexOut = isOutputComplexImpl(~)
            complexOut = false;
        end

        function fixedOut = isOutputFixedSizeImpl(~)
            fixedOut = true;
        end

        function name = getOutputNamesImpl(~)
            name = 'sensor_and_diagnostics';
        end
    end

    methods (Access = private)
        function consumeCompleteLines(obj)
            % Parse only LF-terminated frames. Partial serial packets remain
            % buffered for the next 20 ms step, so they never cause timeout.
            while true
                newlineIndex = find(obj.RxBuffer == uint8(10), 1, 'first');
                if isempty(newlineIndex)
                    break;
                end
                lineBytes = obj.RxBuffer(1:newlineIndex - 1);
                obj.RxBuffer(1:newlineIndex) = [];
                if ~isempty(lineBytes) && lineBytes(end) == uint8(13)
                    lineBytes(end) = [];
                end
                obj.parseLine(string(char(lineBytes)));
            end

            % Protect a long simulation from an unplug/replug garbage burst.
            if numel(obj.RxBuffer) > 8192
                obj.RxBuffer = obj.RxBuffer(end - 4095:end);
                obj.InvalidFrames = obj.InvalidFrames + 1;
            end
        end

        function parseLine(obj, line)
            fields = split(strtrim(line), ',');
            if ~isempty(fields) && strcmpi(strtrim(fields(1)), "DATA")
                fields = fields(2:end); % Accept optional framed live sketch.
            end
            if numel(fields) < 12
                % Ignore startup/header text, but count malformed data rows.
                if strlength(strtrim(line)) > 0 && ...
                        ~contains(lower(line), "time_ms") && ...
                        ~startsWith(upper(strtrim(line)), "READY")
                    obj.InvalidFrames = obj.InvalidFrames + 1;
                end
                return;
            end

            values = str2double(fields(1:12));
            required = values([2 3 4 11 12]);
            cylinderRaw = values(8:10);
            valid = all(isfinite(required)) && ...
                all(isfinite(cylinderRaw)) && ...
                all(abs(required(1:3)) <= 1) && ...
                all(cylinderRaw >= 0 & cylinderRaw <= 1023) && ...
                required(4) >= 0 && required(4) <= 360 && ...
                required(5) >= 0 && required(5) <= 1023;
            if ~valid
                obj.InvalidFrames = obj.InvalidFrames + 1;
                return;
            end

            obj.SensorData(1:3) = required(1:3);
            obj.SensorData(4) = round(required(5));
            obj.SensorData(5) = required(4);
            obj.CylinderRaw = round(cylinderRaw);
            obj.ValidFrames = obj.ValidFrames + 1;
            obj.AgeSeconds = 0;
            obj.Status = 2;
        end

        function connectSerial(obj)
            try
                portName = obj.resolvePort();
                if strlength(portName) == 0
                    obj.disconnectSerial();
                    obj.scheduleReconnect();
                    return;
                end
                obj.SerialDevice = serialport(char(portName), obj.BaudRate, ...
                    'Timeout', 0.05);
                configureTerminator(obj.SerialDevice, "LF");
                flush(obj.SerialDevice);
                obj.RxBuffer = uint8([]);
                obj.Status = 1;
            catch
                obj.disconnectSerial();
                obj.scheduleReconnect();
            end
        end

        function portName = resolvePort(obj)
            portName = strtrim(obj.COMPort);
            if strcmpi(portName, "auto")
                ports = serialportlist("available");
                if isempty(ports)
                    portName = "";
                else
                    portName = ports(1);
                end
            end
        end

        function disconnectSerial(obj)
            obj.SerialDevice = [];
            obj.Status = 0;
            obj.RxBuffer = uint8([]);
        end

        function scheduleReconnect(obj)
            obj.ReconnectTicks = max(1, ...
                round(obj.ReconnectPeriod / obj.SampleTime));
        end
    end

    methods (Static, Access = protected)
        function flag = showSimulateUsingImpl
            flag = false;
        end

        function mode = getSimulateUsingImpl
            mode = "Interpreted execution";
        end
    end
end
