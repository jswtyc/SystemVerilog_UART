*引言*：

*    这是一个基于Ready-Vallid协议的UART设计。
*	支持参数化数据位宽、时钟频率、波特率和奇偶校验。

*详细细节*：

*	两个模块的所有输出端口都已被寄存。
*	发射机的tx端口已寄存，连续发送时，每个比特的时间长度严格相等。
*	接收器处的rx输入端口也被寄存，以获得更好的时序和布线效果。
*	对rx接收时起始位可能出现的抖动添加了滤波效果。
	此外，rx会在每个比特的中心位置上采样四个点，根据这四个值判决。

*最后*：

*	该设计经过了连续发送和接收、随机发送和接收验证，并经过了上板验证。
*	如果您发现任何问题或提供任何指导，我将不胜感激。

