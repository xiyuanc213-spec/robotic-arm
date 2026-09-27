classdef ArduinoPotentiometerReader < matlab.System
    %ARDUINOPOTENTIOMETERREADER Read newline-delimited Arduino ADC values.
    %
    % The Arduino sketch sends one integer (0..1023) followed by LF every
    % 20 ms. This System object is intentionally simulation-only and keeps
    % the last valid value if the cable is disconnected or a line is bad.

    properties (Nontunable)
        COMPort (1,1) string = "COM3"
        BaudRate (1,1) double = 115200
        SampleTime (1,1) double = 0.02
        ReconnectPeriod (1,1) double = 1.0
        InitialADC (1,1) double = 0
    end

    properties (Access = private)
        SerialDevice
        LastADC (1,1) double = 0
        ReconnectTicks (1,1) double = 0
    end

    methods (Access = protected)
        function setupImpl(obj)
            obj.LastADC = min(max(round(obj.InitialADC), 0), 1023);
            obj.ReconnectTicks = 0;
            obj.connectSerial();
        end

        function adc = stepImpl(obj)
            if isempty(obj.SerialDevice)
                obj.ReconnectTicks = obj.ReconnectTicks - 1;
                if obj.ReconnectTicks <= 0
                    obj.connectSerial();
                end
            else
                try
                    % Consume complete lines and retain the newest value.
                    while obj.SerialDevice.NumBytesAvailable > 0
                        line = readline(obj.SerialDevice);
                        candidate = str2double(strtrim(line));
                        if isfinite(candidate) && candidate >= 0 && candidate <= 1023
                            obj.LastADC = round(candidate);
                        end
                    end
                catch
                    obj.SerialDevice = [];
                    obj.scheduleReconnect();
                end
            end
            adc = obj.LastADC;
        end

        function resetImpl(obj)
            obj.LastADC = min(max(round(obj.InitialADC), 0), 1023);
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
            sizeOut = [1 1];
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
            name = 'adc_raw';
        end
    end

    methods (Access = private)
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
            catch
                obj.SerialDevice = [];
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
