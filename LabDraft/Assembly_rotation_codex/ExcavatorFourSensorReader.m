classdef ExcavatorFourSensorReader < matlab.System
    %EXCAVATORFOURSENSORREADER Parse the 12-column excavator Arduino CSV.
    % Output vector:
    % [A0_q_m; A1_q_m; A2_q_m; rotation_raw; rotation_angle_deg; connected]

    properties (Nontunable)
        COMPort (1,1) string = "COM3"
        BaudRate (1,1) double = 115200
        SampleTime (1,1) double = 0.02
        ReconnectPeriod (1,1) double = 1.0
    end

    properties (Access = private)
        SerialDevice
        LastData (6,1) double = [0; 0; 0; 0; 0; 0]
        ReconnectTicks (1,1) double = 0
    end

    methods (Access = protected)
        function setupImpl(obj)
            % q=0 matches the three imported cylinder initial positions;
            % rotation raw=0 maps to the imported -90 degree turret pose.
            obj.LastData = [0; 0; 0; 0; 0; 0];
            obj.ReconnectTicks = 0;
            obj.connectSerial();
        end

        function data = stepImpl(obj)
            if isempty(obj.SerialDevice)
                obj.LastData(6) = 0;
                obj.ReconnectTicks = obj.ReconnectTicks - 1;
                if obj.ReconnectTicks <= 0
                    obj.connectSerial();
                end
            else
                try
                    while obj.SerialDevice.NumBytesAvailable > 0
                        line = readline(obj.SerialDevice);
                        obj.parseLine(line);
                    end
                    obj.LastData(6) = 1;
                catch
                    obj.SerialDevice = [];
                    obj.LastData(6) = 0;
                    obj.scheduleReconnect();
                end
            end
            data = obj.LastData;
        end

        function resetImpl(obj)
            obj.LastData = [0; 0; 0; 0; 0; 0];
            if ~isempty(obj.SerialDevice)
                try
                    flush(obj.SerialDevice);
                catch
                end
            end
        end

        function releaseImpl(obj)
            obj.SerialDevice = [];
        end

        function sampleTime = getSampleTimeImpl(obj)
            sampleTime = createSampleTime(obj, ...
                'Type', 'Discrete', 'SampleTime', obj.SampleTime);
        end

        function sizeOut = getOutputSizeImpl(~)
            sizeOut = [6 1];
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
            name = 'sensor_data';
        end
    end

    methods (Access = private)
        function parseLine(obj, line)
            fields = split(strtrim(line), ',');
            if numel(fields) < 12
                return;
            end
            values = str2double(fields);
            required = values([2 3 4 11 12]);
            if any(~isfinite(required))
                return; % Also ignores the CSV header line.
            end
            obj.LastData(1:3) = values(2:4);
            obj.LastData(4) = min(max(round(values(12)), 0), 1023);
            obj.LastData(5) = min(max(values(11), 0), 360);
        end

        function connectSerial(obj)
            try
                portName = obj.resolvePort();
                if strlength(portName) == 0
                    obj.SerialDevice = [];
                    obj.scheduleReconnect();
                    return;
                end
                obj.SerialDevice = serialport(char(portName), obj.BaudRate, ...
                    'Timeout', max(0.05, obj.SampleTime));
                configureTerminator(obj.SerialDevice, "LF");
                flush(obj.SerialDevice);
                obj.LastData(6) = 1;
            catch
                obj.SerialDevice = [];
                obj.LastData(6) = 0;
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
