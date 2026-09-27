classdef CausalMedianFilter5 < matlab.System
    % Five-sample causal median filter for scalar force measurements.

    properties (Nontunable)
        SampleTime = 0.02
    end

    properties (Access = private)
        Buffer
        Count
    end

    methods (Access = protected)
        function setupImpl(obj, ~)
            obj.Buffer = zeros(5, 1);
            obj.Count = 0;
        end

        function y = stepImpl(obj, u)
            obj.Buffer(1:4) = obj.Buffer(2:5);
            obj.Buffer(5) = u;
            obj.Count = min(obj.Count + 1, 5);
            y = median(obj.Buffer(6-obj.Count:5));
        end

        function resetImpl(obj)
            obj.Buffer(:) = 0;
            obj.Count = 0;
        end

        function sts = getSampleTimeImpl(obj)
            sts = createSampleTime(obj, 'Type', 'Discrete', ...
                'SampleTime', obj.SampleTime, 'OffsetTime', 0);
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
    end
end
