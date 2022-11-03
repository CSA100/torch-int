#include "include/bmm.h"
#include <cstdint>
#include <cuda.h>
#include <cuda_runtime.h>
#include <iostream>
#include <torch/torch.h>

#include <cutlass/core_io.h>
#include <cutlass/cutlass.h>
#include <cutlass/gemm/device/gemm.h>
#include <cutlass/gemm/device/gemm_batched.h>
#include <cutlass/numeric_types.h>
#include <cutlass/util/host_tensor.h>

torch::Tensor bmm_s8t_s8n_s8t(torch::Tensor A, torch::Tensor B,
                              float output_scale) {
  int batch_size = A.size(0);
  int M = A.size(1);
  int N = B.size(1);
  int K = A.size(2);
  auto C = torch::empty({batch_size, M, N}, A.options());

  using LayoutInputA = cutlass::layout::RowMajor;
  using LayoutInputB = cutlass::layout::ColumnMajor;
  using LayoutOutput = cutlass::layout::RowMajor;

  using ElementOutput = int8_t;
  using ElementInputA = int8_t;
  using ElementInputB = int8_t;
  using ElementAccumulator = int32_t;
  using ElementComputeEpilogue = float;

  using EpilogueOp = cutlass::epilogue::thread::LinearCombination<
      ElementOutput, 128 / cutlass::sizeof_bits<ElementOutput>::value,
      ElementAccumulator, ElementComputeEpilogue,
      cutlass::epilogue::thread::ScaleType::NoBetaScaling>;

  using Gemm = cutlass::gemm::device::GemmBatched<
      ElementInputA, LayoutInputA, ElementInputB, LayoutInputB, ElementOutput,
      LayoutOutput, ElementAccumulator, cutlass::arch::OpClassTensorOp,
      cutlass::arch::Sm80, cutlass::gemm::GemmShape<256, 128, 64>,
      cutlass::gemm::GemmShape<64, 64, 64>, cutlass::gemm::GemmShape<16, 8, 32>,
      EpilogueOp>;

  int lda = K;
  int ldb = K;
  int ldc = N;

  long long int batch_stride_A = M * K;
  long long int batch_stride_B = N * K;
  long long int batch_stride_C = M * N;

  Gemm gemm_op;

  cutlass::Status status = gemm_op({{M, N, K},
                                    {A.data_ptr<ElementInputA>(), lda},
                                    batch_stride_A,
                                    {B.data_ptr<ElementInputB>(), ldb},
                                    batch_stride_B,
                                    {C.data_ptr<ElementOutput>(), ldc},
                                    batch_stride_C,
                                    {C.data_ptr<ElementOutput>(), ldc},
                                    batch_stride_C,
                                    {output_scale},
                                    batch_size});

  if (status != cutlass::Status::kSuccess) {
    std::cout << "cutlass error code: " << (int)status << std::endl;
  }
  return C;
}
