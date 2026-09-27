function diagnose_arduino_four_sensor_stream(comPort, testSeconds)
%DIAGNOSE_ARDUINO_FOUR_SENSOR_STREAM Test Arduino independently of Simulink.
%
% Examples:
%   diagnose_arduino_four_sensor_stream("auto", 5)
%   diagnose_arduino_four_sensor_stream("COM4", 10)

if nargin < 1 || strlength(string(comPort)) == 0
    comPort = "auto";
else
    comPort = string(comPort);
end
if nargin < 2
    testSeconds = 5;
end

ports = serialportlist("available");
fprintf('Available serial ports: ');
if isempty(ports)
    fprintf('(none)\n');
    error(['No serial port is available. Check USB cable/driver and Device ' ...
        'Manager. This computer cannot receive Arduino data yet.']);
end
fprintf('%s\n', strjoin(cellstr(ports), ', '));

if strcmpi(comPort, "auto")
    comPort = ports(1);
end
fprintf('Opening %s at 115200 baud...\n', comPort);

device = serialport(char(comPort), 115200, 'Timeout', 0.2);
cleanupDevice = onCleanup(@() delete(device)); %#ok<NASGU>
configureTerminator(device, "LF");
flush(device);

% Many Arduino boards reset when the serial port opens.
pause(2);
validFrames = 0;
invalidFrames = 0;
printedFrames = 0;
startTime = tic;
while toc(startTime) < testSeconds
    if device.NumBytesAvailable == 0
        pause(0.01);
        continue;
    end
    try
        line = strtrim(readline(device));
    catch
        continue;
    end
    if strlength(line) == 0
        continue;
    end
    if printedFrames < 8
        fprintf('RX: %s\n', line);
        printedFrames = printedFrames + 1;
    end

    fields = split(line, ',');
    if ~isempty(fields) && strcmpi(strtrim(fields(1)), "DATA")
        fields = fields(2:end);
    end
    if numel(fields) < 12
        if ~contains(lower(line), "time_ms") && ...
                ~startsWith(upper(line), "READY")
            invalidFrames = invalidFrames + 1;
        end
        continue;
    end
    values = str2double(fields(1:12));
    required = values([2 3 4 11 12]);
    if all(isfinite(required)) && required(5) >= 0 && required(5) <= 1023
        validFrames = validFrames + 1;
    else
        invalidFrames = invalidFrames + 1;
    end
end

fprintf('\nValid frames: %d\nInvalid frames: %d\n', validFrames, invalidFrames);
if validFrames == 0
    error(['Serial port opened, but no valid 12-column sensor frame was ' ...
        'received. Confirm the new four-sensor sketch is uploaded and the ' ...
        'baud rate is 115200.']);
end
fprintf('PASS: Arduino four-sensor stream is valid.\n');
end
