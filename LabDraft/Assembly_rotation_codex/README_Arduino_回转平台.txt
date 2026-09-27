挖掘机回转平台 Arduino 输入版

主模型：Assem_rotation_Arduino_codex.slx
Arduino 程序：Arduino_Potentiometer_Serial.ino
串口读取类：ArduinoPotentiometerReader.m

一、Arduino 接线与程序
1. 电位器两端连接 5V 和 GND，滑动端连接 A0。
2. 用 Arduino IDE 打开并烧录 Arduino_Potentiometer_Serial.ino。
3. 程序以 115200 baud、50 Hz 发送 0..1023，每个数值单独一行。
4. 烧录后关闭 Arduino IDE 的 Serial Monitor/Serial Plotter，串口不能被两个程序同时占用。

二、Simulink 配置
1. 在 MATLAB 中把当前文件夹切换到本模型所在文件夹。
2. 打开 Assem_rotation_Arduino_codex.slx。
3. 双击 Arduino_ADC_Reader 块，把 COMPort 改成设备管理器中的端口，例如 COM4。
   也可以填 auto；如果有多个串口，建议明确填写 COM 号。
4. 保持 BaudRate=115200、SampleTime=0.02。
5. 点击 Run。模型已经启用 1:1 Simulation Pacing，使仿真时间与真实时间大致同步。

三、角度换算
传感器原始值先限制在 0..1023，再经过低通滤波：
sensor_angle_deg = adc * 359 / 1023
joint_command_deg = sensor_angle_deg - 90

默认 -90 deg 偏置用于对齐原 CAD 模型的初始回转角。若实际零位不同，修改
Sensor_Zero_Offset_deg 块的 Bias 参数。当前映射为：
ADC 0    -> 关节命令 -90 deg
ADC 1023 -> 关节命令 269 deg

四、断线行为
Arduino 未连接或串口数据无效时，读取块保持最后一个有效值，并每 1 秒重连。
初始 ADC 值为 0，因此未连接时命令保持在 -90 deg 附近，不会突然运动。

五、输出
Arduino_ADC_raw：原始 ADC 值。
Arduino_sensor_angle_deg：换算后的 0..359 deg 传感器角度。
platform_angle_deg：Simscape 模型的实际回转角。
