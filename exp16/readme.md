# exp16修正记录

## 1. IF stage:
- pfs_flush:
```
    reg pfs_reflush;
always @(posedge clk) begin
    if(reset)
        pfs_reflush <= 1'b0;
    else if(inst_sram_en && (fs_reflush | br_taken & ~br_stall | (br_stall | br_stall_reg)& inst_sram_addr_ok ) )
        pfs_reflush <= 1'b1;
    else if(inst_sram_data_ok)
        pfs_reflush <= 1'b0;
end
```

主要原因是：

发出读请求后，由于类SRAM 总线允许中途更改请求，而AXI 总线不允许中途更改，因此哪怕错误的请求还没被接收，我们也让其继续发完，然后再阻塞pre-IF 级，忽视后续返回的指令，再重新发正确的请求。也就是为什么需要pfs_reflush信号的原因

设计br_stall指令的初衷是如果ID 级是转移指令，而它的前一条指令是load 指令，又恰好存在数据相关，那么ID 级由于延迟会无法通过前递获得数据。为此在ID 级加入一个br_stall 信号并传给pre-IF 级，使其在发生这种相关时将req 拉低，不要发送取指请求，直到相关解除后才发送。

但是现在考虑到因为在指令进入ID 级、拉高br_stall 前，它的后一条指令可能已经开始发送取指请求，原本的读请求的判断逻辑是
**assign inst_sram_en       = fs_allowin & ~br_stall & pfs_valid;**
而现在不能仅仅通过在br_stall 为1 时拉低req 来处理br_stall，而是需要先发完再取消。

现在的pfs阶段主要的控制逻辑更改为：
```
assign pfs_ready_go = inst_sram_en & inst_sram_addr_ok &  ~( fs_reflush | br_taken & ~br_stall | br_stall | pfs_reflush );           

assign inst_sram_en = fs_allowin & pfs_valid & ~pfs_reflush ;
```
对于pfs_ready_go来讲,当其他流水及遇到异常需要刷新和跳转指令时,信号将会拉低,代表上一条发出的取指指令无效,不会流水到IF阶段.


- fs_inst_cancel信号
```
assign fs_inst_cancel = fs_reflush | fs_reflush_reg | br_taken & ~br_stall | br_taken_reg;
```
现在cancel信号不再需要用一个寄存器存住,因为已经保证了pfs_stage发出来的指令都将是有效的,br_stall_reg也存住已产生的跳转指令请求的信号.





