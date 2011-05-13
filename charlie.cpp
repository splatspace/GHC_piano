
/*
 * CharliePlexing Experiments
 */

int set[26][8] = 
{
	{ 0,1,2,2,2,2,2,2 },
	{ 1,0,2,2,2,2,2,2 },

	{ 2,1,0,2,2,2,2,2 },
	{ 2,0,1,2,2,2,2,2 },

	{ 2,2,1,0,2,2,2,2 },
	{ 2,2,0,1,2,2,2,2 },

	{ 2,2,2,1,0,2,2,2 },
	{ 2,2,2,0,1,2,2,2 },

	{ 2,2,2,2,0,1,2,2 },
	{ 2,2,2,2,1,0,2,2 },

	{ 2,2,2,2,2,0,1,2 },
	{ 2,2,2,2,2,1,0,2 },

	{ 2,2,2,2,2,2,1,0 },
	{ 2,2,2,2,2,2,0,1 },

	{ 1,2,0,2,2,2,2,2 },
	{ 0,2,1,2,2,2,2,2 },

	{ 2,1,2,0,2,2,2,2 },
	{ 2,0,2,1,2,2,2,2 },

	{ 2,2,1,2,0,2,2,2 },
	{ 2,2,0,2,1,2,2,2 },

	{ 2,2,2,1,2,0,2,2 },
	{ 2,2,2,0,2,1,2,2 },

	{ 2,2,2,2,1,2,0,2 },
	{ 2,2,2,2,0,2,1,2 },

	{ 2,2,2,2,2,1,2,0 },
	{ 2,2,2,2,2,0,2,1 }

};

int mode[]  = { OUTPUT, OUTPUT, INPUT };
int value[] = {      0,      1,     0 };

void led(int i, int ms);

void setup()
{
   Serial.begin(115200);
}

// Nearly all of the pins are high or input/high all the time.
// Only one pin is zero at a time, to turn on a particular LED.
// If we do all the setup before setting this pin low, then
// immediately set this pin high again. We can get an isolated
// single LED on-at-a-time in a perfectly controlled way.
//
// This is important for the multiplexed reflective-IR sensor.
//

void loop()
{
int i,j;

   for (i=0; i<9; i++) // FOR TEN SETTINGS
   {
	int lowpin, lowset;
	for (j=0; j<9; j++) // EIGHT PINS 2-10
	{
		int n = set[i][j];
		if (n == 0) lowpin = j+2;
		else
		{
			pinMode(j+2, mode[n]);
			digitalWrite(j+2, value[n]);
		}
		Serial.print(j);Serial.print(" ");
	}
	Serial.println();

	// Now light the LED for one second.
		pinMode(lowpin, OUTPUT);
		digitalWrite(lowpin, 0);
		delay(1000);
		pinMode(lowpin, INPUT);

	// Then pause for two seconds
	delay(2000);
   }

   for (i=0; i<10; i++) // FOR TEN SETTINGS
   {
	led(i,100);
   }
}

void led(int i, int ms)
{
	int j, lowpin;
	for (j=0; j<9; j++) // EIGHT PINS 2-10
	{
		int n = set[i][j];
		if (n == 0) lowpin = j+2;
		else
		{
			pinMode(j+2, mode[n]);
			digitalWrite(j+2, value[n]);
		}
	}
	pinMode(lowpin, OUTPUT);
	digitalWrite(lowpin, 0);
	delay(ms);
	pinMode(lowpin, INPUT);
}

