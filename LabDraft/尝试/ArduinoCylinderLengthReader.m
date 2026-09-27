classdef ArduinoCylinderLengthReader < matlab.System
    % Read the latest A0/A1/A2 displacement CSV row from Arduino.
    % Output is a 3-element vector [A0 A1 A2] in metres.

    properties (Nontunable)
        Port = "COM3"
        BaudRate = 115200
        SampleTime = 0.02
        Timeout = 0.05
    end

    properties (Access = private)
        Serial
        LastValue = zeros(1, 3)
    end

    methods (Access = protected)
        function setupImpl(obj)
            obj.Serial = serialport(obj.Port, obj.BaudRate, "Timeout", obj.Timeout);
            configureTerminator(obj.Serial, "LF");
            flush(obj.Serial);
            obj.LastValue = zeros(1, 3);
        end

        function y = stepImpl(obj)
            % Wait for a complete line so fast Simulink simulation time cannot
            % repeatedly reuse the same physical Arduino sample.
            deadline = tic;
            while toc(deadline) < obj.Timeout
                try
                    line = strtrim(readline(obj.Serial));
                catch
                    break;
                end
                values = sscanf(line, '%f,%f,%f,%f,%f,%f,%f,%f,%f,%f');
                if numel(values) >= 4 && all(isfinite(values(2:4)))
                    obj.LastValue = values(2:4).';
                    break;
                end
            end
            y = obj.LastValue;
        end

        function resetImpl(obj)
            if ~isempty(obj.Serial) && isvalid(obj.Serial), flush(obj.Serial); end
            obj.LastValue = zeros(1, 3);
        end

        function releaseImpl(obj)
            if ~isempty(obj.Serial) && isvalid(obj.Serial), delete(obj.Serial); end
            obj.Serial = [];
        end

        function sts = getSampleTimeImpl(obj)
            sts = createSampleTime(obj, 'Type', 'Discrete', ...
                'SampleTime', obj.SampleTime, 'OffsetTime', 0);
        end

        function sizeOut = getOutputSizeImpl(~)
            sizeOut = [1 3];
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
    end
end
