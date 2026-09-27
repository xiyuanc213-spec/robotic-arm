四传感器实时诊断版——现实机构运动但 Simulink 不动时使用

主模型：Assem_rotation_4Sensors_live_codex.slx
读取类：ExcavatorFourSensorReaderLive.m
独立串口测试：diagnose_arduino_four_sensor_stream.m

一、先做独立串口测试
1. Arduino 连接 USB，并烧录：
   A0_A1_A2_Rotation_Monitor\A0_A1_A2_Rotation_Monitor.ino
2. 关闭 Arduino IDE 的 Serial Monitor 和 Serial Plotter。
3. MATLAB 当前文件夹切换到 Assembly_rotation_codex。
4. 在命令窗口运行：
   diagnose_arduino_four_sensor_stream("auto",5)
   如果有多个 COM 口，请改成明确端口，例如：
   diagnose_arduino_four_sensor_stream("COM4",5)
5. 只有看到 PASS 后再运行 Simulink。

二、Simulink 诊断状态
进入 Four_Sensor_Interface，可以看到 Arduino_CSV_Reader。
默认 COMPort=auto；如有多个串口，请改成明确的 COM 号。

Serial_Status_Code：
0 = Windows/MATLAB 没有可用串口，或串口被其他软件占用
1 = 串口已打开，但尚未收到有效的 12 列数据
2 = 正常收到数据
3 = 曾收到数据，但超过 0.5 秒没有新数据

Valid_Frame_Count 应持续增加；Invalid_Frame_Count 应保持接近 0；
Frame_Age_s 在正常接收时应不断回到接近 0。
A0_Raw/A1_Raw/A2_Raw/Rotation_ADC_Display 应随现实传感器运动而变化。

三、TEST / ARDUINO 模式
顶层 Input_Mode 块：
0 = Arduino（默认）
1 = 内置测试信号

先把 Input_Mode 设为 1：
- 如果 Simulink 挖掘机开始运动，机械连接是正常的，问题只在串口、COM 口或数据格式。
- 如果测试模式也不运动，再检查 Mechanics Explorer 是否打开、仿真是否真的处于 Running。

确认测试模式会动后，把 Input_Mode 改回 0，再运行真实传感器。

四、关键注意事项
- 仿真必须处于 Running，模型默认 StopTime=inf、1:1 Simulation Pacing。
- Arduino IDE 串口监视器必须关闭，否则 Simulink 无法占用同一 COM 口。
- Arduino 输出必须为 115200 baud、每行 12 列。
- 如果原始 ADC 会变化但 A0/A1/A2 的 q 不变化，说明原标定区间把 q 限制在端点，需要重新标定 adcAtWorkMin/adcAtWorkMax。
- 本读取器按字节非阻塞缓存，不会因半行串口数据而超时断线。
- 若电脑完全没有显示 COM 口，请更换支持数据传输的 USB 线并安装板卡驱动。
