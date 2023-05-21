/*
 * Show Random Circles in Screen
 * To manually build:
 * make && make -C examples/random_circles
 */

//Include durango lib
#include <durango.h>


int main(){
    //local variables
	int x,y,ratio,color;
    //init random Seed
    random_init(115);
    //draw black Screen
    drawFullScreen(BLACK);
	while(1) {
        //calculate coords ratio and color using random
        x=(random())%128;
        y=(random())%128;
        ratio=random()+10;
        color = (random())%16;
        //Draw Circles using the previous calculated values
        drawCircle(x,y,ratio,COLOR_BY_INDEX[color]);
		// Wait for VSYNC
        waitVSync();
	}
	
	return 0;
}
