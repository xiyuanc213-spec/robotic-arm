挖掘机回转平台 Simulink 修改版

主模型：Assem_rotation_codex.slx

已经完成的修改：
1. Revolute10 是 torretta_XCGM（回转平台）与 Basic Structure（固定底座）之间的关节。
2. Revolute10 使用扭矩输入，并启用角度和角速度反馈。
3. 外部角度命令经过 PD 控制器（Kp=2000，Kd=1000）转换成回转扭矩，避免液压闭环过约束。
4. 模型默认使用 Demo_Sine_45deg：中心 -90 deg，幅值 45 deg，角频率 0.35 rad/s。
5. 双击 Command_Select 手动开关，可以改用 platform_angle_cmd_deg 外部输入。
6. platform_angle_deg、Platform_Angle_Scope 和 Platform_Angle_Log 输出/记录实际回转角度。

使用方法：
- 在 MATLAB 中把当前文件夹切换到本文件夹。
- 打开 Assem_rotation_codex.slx，直接运行即可看到转台往复回转。
- 若使用外部命令，切换 Command_Select；输入单位为 deg，命令是绝对关节角。
- 导入初始角为 -90 deg，因此自定义信号最好从 -90 deg 平滑开始。
