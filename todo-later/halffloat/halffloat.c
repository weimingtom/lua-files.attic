//adapted from: http://stackoverflow.com/questions/1659440/32-bit-to-16-bit-floating-point-conversion
//handles all subnormal values, both infinities, quiet NaNs, signaling NaNs, and negative zero.
//alternative implementation based on lookup tables: ftp://ftp.fox-toolkit.org/pub/fasthalffloatconversion.pdf
#include <inttypes.h>

typedef union {
	float f;
	int32_t si;
	uint32_t ui;
} Bits;

int shift = 13;
int shiftSign = 16;

int32_t infN = 0x7F800000; // flt32 infinity
int32_t maxN = 0x477FE000; // max flt16 normal as a flt32
int32_t minN = 0x38800000; // min flt16 normal as a flt32
int32_t signN = 0x80000000; // flt32 sign bit

int32_t mulN = 0x52000000; // (1 << 23) / minN
int32_t mulC = 0x33800000; // minN / (1 << (23 - shift))

int32_t subC = 0x003FF; // max flt32 subnormal down shifted
int32_t norC = 0x00400; // min flt32 normal down shifted

int32_t infC;
int32_t nanN;
int32_t maxC;
int32_t minC;
int32_t signC;

int32_t maxD;
int32_t minD;

void halffloat_init() {
	infC = infN >> shift;
	nanN = (infC + 1) << shift; // minimum flt16 nan as a flt32
	maxC = maxN >> shift;
	minC = minN >> shift;
	signC = signN >> shiftSign; // flt16 sign bit

	maxD = infC - maxC - 1;
	minD = minC - subC - 1;
}

uint16_t halffloat_compress(float value)
{
	Bits v, s;
	v.f = value;
	uint32_t sign = v.si & signN;
	v.si ^= sign;
	sign >>= shiftSign; // logical shift
	s.si = mulN;
	s.si = s.f * v.f; // correct subnormals
	v.si ^= (s.si ^ v.si) & -(minN > v.si);
	v.si ^= (infN ^ v.si) & -((infN > v.si) & (v.si > maxN));
	v.si ^= (nanN ^ v.si) & -((nanN > v.si) & (v.si > infN));
	v.ui >>= shift; // logical shift
	v.si ^= ((v.si - maxD) ^ v.si) & -(v.si > maxC);
	v.si ^= ((v.si - minD) ^ v.si) & -(v.si > subC);
	return v.ui | sign;
}

float halffloat_decompress(uint16_t value)
{
	Bits v;
	v.ui = value;
	int32_t sign = v.si & signC;
	v.si ^= sign;
	sign <<= shiftSign;
	v.si ^= ((v.si + minD) ^ v.si) & -(v.si > subC);
	v.si ^= ((v.si + maxD) ^ v.si) & -(v.si > maxC);
	Bits s;
	s.si = mulC;
	s.f *= v.si;
	int32_t mask = -(norC > v.si);
	v.si <<= shift;
	v.si ^= (s.si ^ v.si) & mask;
	v.si |= sign;
	return v.f;
}

