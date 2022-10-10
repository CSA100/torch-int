import torch
from torch_int.nn import Int8Linear
from utils import bench_model
import argparse

@torch.no_grad()
def bench_quant_linear(args):
    SEQ_LEN = args.seq_len
    C1, C2 = args.C1, args.C2
    print('SEQ_LEN = ', SEQ_LEN)
    print('C1 = ', C1)
    print('C2 = ', C2)
    print('precision = ', args.precision)
    model = torch.nn.Linear(C1, C2).half()
    dummy_input = torch.randn(SEQ_LEN, C1).half()

    if args.precision == 'int8':
        model = Int8Linear.from_float(model)

    bench_model(model, dummy_input, num_iter=10000)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--seq-len', type=int, default=128)
    parser.add_argument('--C1', type=int, default=12288)
    parser.add_argument('--C2', type=int, default=12288)
    parser.add_argument('--precision', type=str, default='int8')
    args = parser.parse_args()
    bench_quant_linear(args)
