挖掘机三个位移传感器 + 一个回转传感器联合仿真

主模型：Assem_rotation_4Sensors_codex.slx
Arduino 程序：A0_A1_A2_Rotation_Monitor.ino
串口读取类：ExcavatorFourSensorReader.m

一、接线
- 原三个位移传感器保持 A0、A1、A2 不变。
- 回转电位器两端接 5V 和 GND，滑动端接 A3。
- 若你的板卡不是 5 V 板，请使用板卡规定的模拟参考电压。

二、Arduino 数据格式
串口：115200 baud，50 Hz，每行 12 列：
time_ms,A0_q_m,A1_q_m,A2_q_m,A0_length_mm,A1_length_mm,A2_length_mm,A0_raw,A1_raw,A2_raw,rotation_angle_deg,rotation_raw

前三个位移传感器的原标定参数和前 10 列顺序均未改变。
回转角计算：rotation_angle_deg = rotation_raw * 360 / 1023。

三、Simulink 使用方法
1. 烧录 A0_A1_A2_Rotation_Monitor.ino。
2. 关闭 Arduino IDE 的 Serial Monitor/Serial Plotter。
3. 在 MATLAB 中进入 Assembly_rotation_codex 文件夹。
4. 打开 Assem_rotation_4Sensors_codex.slx。
5. 双击 Four_Sensor_Interface 内的 Arduino_CSV_Reader。
6. 将 COMPort 改为实际端口，例如 COM4；也可以填 auto。
7. 点击 Run。仿真默认启用 1:1 Simulation Pacing，StopTime=inf，手动停止即可。

四、模型中的对应关系
- A0_q_m -> A0_1（铲斗液压缸 Prismatic Joint）
- A1_q_m -> A1_1（斗杆液压缸 Prismatic Joint）
- A2_q_m -> A2_1（动臂液压缸 Prismatic Joint）
- rotation_raw -> 0..1023 限幅 -> 5 Hz 低通 -> 360/1023 -> -90 deg 偏置 -> 回转 PD 扭矩控制器

回转默认映射：
- ADC 0 -> 关节命令 -90 deg（CAD 初始角）
- ADC 1023 -> 关节命令 270 deg

如实际安装零位不同，修改 Rotation_Zero_Offset_deg 的 Bias 参数。

五、安全与断线行为
- 三个位移 q 值在 Simulink 内再次限制到原标定范围。
- 非法 CSV 行和开机表头会被忽略。
- 串口断开时保持最后有效的传感器值，并每 1 秒尝试重连。
- 未连接时初始 q=0、回转 raw=0，模型保持接近导入初始姿态。
