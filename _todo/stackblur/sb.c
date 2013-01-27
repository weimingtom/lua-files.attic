//go@ gcc sb.c -O3 -o ../../bin/stackblur.dll -shared
// Stack Blur Algorithm by Mario Klingemann <mario@quasimondo.com>

#include <stdint.h>
#include <stdlib.h>
#include "branchless.c"

//from http://www.quasimondo.com/StackBlurForCanvas/StackBlur.js
const int16_t mul_table[257] = {
	512,512,456,512,328,456,335,512,405,328,271,456,388,335,292,512,
	454,405,364,328,298,271,496,456,420,388,360,335,312,292,273,512,
	482,454,428,405,383,364,345,328,312,298,284,271,259,496,475,456,
	437,420,404,388,374,360,347,335,323,312,302,292,282,273,265,512,
	497,482,468,454,441,428,417,405,394,383,373,364,354,345,337,328,
	320,312,305,298,291,284,278,271,265,259,507,496,485,475,465,456,
	446,437,428,420,412,404,396,388,381,374,367,360,354,347,341,335,
	329,323,318,312,307,302,297,292,287,282,278,273,269,265,261,512,
	505,497,489,482,475,468,461,454,447,441,435,428,422,417,411,405,
	399,394,389,383,378,373,368,364,359,354,350,345,341,337,332,328,
	324,320,316,312,309,305,301,298,294,291,287,284,281,278,274,271,
	268,265,262,259,257,507,501,496,491,485,480,475,470,465,460,456,
	451,446,442,437,433,428,424,420,416,412,408,404,400,396,392,388,
	385,381,377,374,370,367,363,360,357,354,350,347,344,341,338,335,
	332,329,326,323,320,318,315,312,310,307,304,302,299,297,294,292,
	289,287,285,282,280,278,275,273,271,269,267,265,263,261,259
};

const int8_t shg_table[257] = {
	 9, 11, 12, 13, 13, 14, 14, 15, 15, 15, 15, 16, 16, 16, 16, 17,
	17, 17, 17, 17, 17, 17, 18, 18, 18, 18, 18, 18, 18, 18, 18, 19,
	19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 20, 20, 20,
	20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 21,
	21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21,
	21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 22, 22, 22, 22, 22, 22,
	22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22,
	22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 23,
	23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
	23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
	23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
	23, 23, 23, 23, 23, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
	24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
	24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
	24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
	24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24
};

#define dv(sum) (((sum) * mul_sum) >> shg_sum)

void stack_blur_argb32(uint8_t* pix, int32_t w, int32_t h, int32_t radius) {
   if (radius < 1 || radius > 256) return;

    int32_t wm  = w-1;
    int32_t hm  = h-1;
    int32_t wh  = w*h;
    int32_t div = radius+radius+1;

	int32_t* r = malloc(w * h * 4);
	int32_t* g = malloc(w * h * 4);
	int32_t* b = malloc(w * h * 4);
	int32_t* a = malloc(w * h * 4);

    int32_t rsum, gsum, bsum, asum, x, y, i, yp, yi, yw;
    uint8_t* p;
    int32_t* vmin = malloc(4 * max(w,h));

    int32_t divsum = (div+1)>>1;
    divsum *= divsum;
    int32_t* dv = malloc(4 * 256*divsum);
    for (i=0; i < 256*divsum; ++i) {
        dv[i] = (i/divsum);
    }

    yw = yi = 0;

    int32_t** stack = malloc(4 * div);
    int32_t* stack_buf = malloc(4 * div);
	 for(i = 0; i < div; ++i)
		stack[i] = stack_buf + (i * 4);

    int32_t stackpointer;
    int32_t stackstart;
    int32_t* sir;
    int32_t rbs;
    int32_t r1 = radius+1;
    int32_t routsum, goutsum, boutsum, aoutsum;
    int32_t rinsum, ginsum, binsum, ainsum;

    for (y = 0; y < h; ++y){
        rinsum = ginsum = binsum = ainsum
               = routsum = goutsum = boutsum = aoutsum
               = rsum = gsum = bsum = asum = 0;
        for(i =- radius; i <= radius; ++i) {
            p = pix + (4 * (yi+min(wm,max(i,0))));
            sir = stack[i+radius];
            sir[0] = p[0];
            sir[1] = p[1];
            sir[2] = p[2];
            sir[3] = p[3];

            rbs = r1-abs(i);
            rsum += sir[0]*rbs;
            gsum += sir[1]*rbs;
            bsum += sir[2]*rbs;
            asum += sir[3]*rbs;

            if (i > 0){
                rinsum += sir[0];
                ginsum += sir[1];
                binsum += sir[2];
                ainsum += sir[3];
            } else {
                routsum += sir[0];
                goutsum += sir[1];
                boutsum += sir[2];
                aoutsum += sir[3];
            }
        }
        stackpointer = radius;

        for (x=0; x < w; ++x) {

            r[yi] = dv[rsum];
            g[yi] = dv[gsum];
            b[yi] = dv[bsum];
            a[yi] = dv[asum];

            rsum -= routsum;
            gsum -= goutsum;
            bsum -= boutsum;
            asum -= aoutsum;

            stackstart = stackpointer-radius+div;
            sir = stack[stackstart%div];

            routsum -= sir[0];
            goutsum -= sir[1];
            boutsum -= sir[2];
            aoutsum -= sir[3];

            if (y == 0) {
                vmin[x] = min(x+radius+1,wm);
            }
            p = pix + 4 * (yw+vmin[x]);

            sir[0] = p[0];
            sir[1] = p[1];
            sir[2] = p[2];
            sir[3] = p[3];

            rinsum += sir[0];
            ginsum += sir[1];
            binsum += sir[2];
            ainsum += sir[3];

            rsum += rinsum;
            gsum += ginsum;
            bsum += binsum;
            asum += ainsum;

            stackpointer = (stackpointer+1)%div;
            sir = stack[(stackpointer)%div];

            routsum += sir[0];
            goutsum += sir[1];
            boutsum += sir[2];
            aoutsum += sir[3];

            rinsum -= sir[0];
            ginsum -= sir[1];
            binsum -= sir[2];
            ainsum -= sir[3];

            ++yi;
        }
        yw += w;
    }
    for (x=0; x < w; ++x){
        rinsum = ginsum = binsum = ainsum
               = routsum = goutsum = boutsum = aoutsum
               = rsum = gsum = bsum = asum = 0;

        yp =- radius * w;

        for(i=-radius; i <= radius; ++i) {
            yi=max(0,yp)+x;

            sir = stack[i+radius];

            sir[0] = r[yi];
            sir[1] = g[yi];
            sir[2] = b[yi];
            sir[3] = a[yi];

            rbs = r1-abs(i);

            rsum += r[yi]*rbs;
            gsum += g[yi]*rbs;
            bsum += b[yi]*rbs;
            asum += a[yi]*rbs;

            if (i > 0) {
                rinsum += sir[0];
                ginsum += sir[1];
                binsum += sir[2];
                ainsum += sir[3];
            } else {
                routsum += sir[0];
                goutsum += sir[1];
                boutsum += sir[2];
                aoutsum += sir[3];
            }

            if (i < hm){
                yp += w;
            }
        }

        yi = x;
        stackpointer = radius;

        for (y=0; y < h; ++y){
            pix[4 * yi + 0] = dv[rsum];
				pix[4 * yi + 1] = dv[gsum];
				pix[4 * yi + 2] = dv[bsum];
				pix[4 * yi + 3] = dv[asum];

            rsum -= routsum;
            gsum -= goutsum;
            bsum -= boutsum;
            asum -= aoutsum;

            stackstart = stackpointer-radius+div;
            sir = stack[stackstart%div];

            routsum -= sir[0];
            goutsum -= sir[1];
            boutsum -= sir[2];
            aoutsum -= sir[3];

            if (x==0){
                vmin[y] = min(y+r1,hm)*w;
            }
            i = x+vmin[y];

            sir[0] = r[i];
            sir[1] = g[i];
            sir[2] = b[i];
            sir[3] = a[i];

            rinsum += sir[0];
            ginsum += sir[1];
            binsum += sir[2];
            ainsum += sir[3];

            rsum += rinsum;
            gsum += ginsum;
            bsum += binsum;
            asum += ainsum;

            stackpointer = (stackpointer+1)%div;
            sir = stack[stackpointer];

            routsum += sir[0];
            goutsum += sir[1];
            boutsum += sir[2];
            aoutsum += sir[3];

            rinsum -= sir[0];
            ginsum -= sir[1];
            binsum -= sir[2];
            ainsum -= sir[3];

            yi += w;
        }
    }
    free(r);
    free(g);
    free(b);
    free(a);
    free(vmin);
    free(dv);
    free(stack);
    free(stack_buf);
}
