classdef CylinderTrajectoryConditioner < matlab.System
    % Zero the first measured pose and apply synchronized velocity and
    % acceleration limits to three cylinder position commands.

    properties (Nontunable)
        MaxSpeed = 0.2          % m/s
        MaxAcceleration = 0.5   % m/s^2
        SampleTime = 0.02       % s
        InputScale = 1          % use 0.001 if Arduino values are in mm
    end

    properties (Access = private)
        IsInitialized
        InitialPosition
        LimitedPosition
        LimitedVelocity
    end

    methods (Access = protected)
        function setupImpl(obj, ~)
            obj.IsInitialized = false;
            obj.InitialPosition = zeros(1,3);
            obj.LimitedPosition = zeros(1,3);
            obj.LimitedVelocity = zeros(1,3);
        end

        function y = stepImpl(obj, u)
            measured = reshape(u,1,3) * obj.InputScale;
            if ~obj.IsInitialized
                obj.InitialPosition = measured;
                obj.LimitedPosition(:) = 0;
                obj.LimitedVelocity(:) = 0;
                obj.IsInitialized = true;
            end
            target = measured - obj.InitialPosition;
            dt = obj.SampleTime;
            for k = 1:3
                errorPosition = target(k) - obj.LimitedPosition(k);
                brakingSpeed = sqrt(max(0, 2*obj.MaxAcceleration*abs(errorPosition)));
                desiredVelocity = sign(errorPosition) * min(obj.MaxSpeed, brakingSpeed);
                maxDeltaVelocity = obj.MaxAcceleration * dt;
                deltaVelocity = min(max(desiredVelocity-obj.LimitedVelocity(k), ...
                    -maxDeltaVelocity), maxDeltaVelocity);
                newVelocity = obj.LimitedVelocity(k) + deltaVelocity;
                increment = newVelocity * dt;
                if errorPosition ~= 0 && sign(increment) == sign(errorPosition) && ...
                        abs(increment) >= abs(errorPosition)
                    obj.LimitedPosition(k) = target(k);
                    obj.LimitedVelocity(k) = 0;
                else
                    obj.LimitedPosition(k) = obj.LimitedPosition(k) + increment;
                    obj.LimitedVelocity(k) = newVelocity;
                end
            end
            y = obj.LimitedPosition;
        end

        function resetImpl(obj)
            obj.IsInitialized = false;
            obj.InitialPosition(:) = 0;
            obj.LimitedPosition(:) = 0;
            obj.LimitedVelocity(:) = 0;
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
