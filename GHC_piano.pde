/*
 * Direct Digital Synthesis (DDS) Sine Generator
 * Timer2 generates the  31250 KHz Clock Interrupt
 *
 * KHM 2009 / Martin Nawrath, Academy of Media Arts Cologne
 */
#include <Tone.h>
#include "avr/pgmspace.h"
#define PARAM_SLOW_ATTACK  3
#define PARAM_SLOW_DECAY   4
#define PARAM_MINOR        5
#define PARAM_MAJOR        1
#define PARAM_HARMONIC     2
#define PARAM_CHROMATIC    3

// 256 element flash memory array of one sinewave cycle

PROGMEM  prog_uchar chromatic[]  = {
	NOTE_C3,
	NOTE_CS3,
	NOTE_D3,
	NOTE_DS3,
	NOTE_E3,
	NOTE_F3,
	NOTE_FS3,
	NOTE_G3,
	NOTE_GS3,
	NOTE_A3,
	NOTE_AS3,
	NOTE_B3,
	NOTE_C4
};

PROGMEM  prog_uchar minormajor[]  = {
	NOTE_A3,
	NOTE_B3,
	NOTE_C3,
	NOTE_D3,
	NOTE_E3,
	NOTE_F3,
	NOTE_G3,
	NOTE_A3,
	NOTE_B3,
	NOTE_C4,
	NOTE_D3,
	NOTE_E3,
	NOTE_F3,
	NOTE_G3
};

Tone notePlayer[6];

int ntes[12];
byte notes[12];
byte previous[12];
byte k;

// Table of input pin assignments:
//  The first ten are digital Inputs, skipping over 11
//  The last two, note[10-11] are analog inputs

int    note[] = { 2,3,4,5,6,7,8,9,10,12,0,1 };

// Status of the six note generators
byte   busy[] = { 0,0,0,0,0,0 };

void setup()
{
  byte i;
  pinMode(11, OUTPUT);        // sets the digital pin as output
  Serial.begin(115200);       // connect to the serial port
  Serial.println("GHC");

  for(i=0;i<10;i++)
  {
	pinMode(note[i], INPUT);
	digitalWrite(note[i], HIGH);
  }
  delay(300);
  int prog = getValue();
  printParameters(prog);

prog_uchar *noteptr;

  if (   (prog&3 == PARAM_MINOR)
      || (prog&3 == PARAM_HARMONIC))  noteptr = minormajor;
  else if (prog&3 == PARAM_MAJOR)     noteptr = minormajor + 3;
  else if (prog&3 == PARAM_CHROMATIC)  noteptr = chromatic;

  for(i=0;i<12;i++)
  {
    ntes[i] = pgm_read_byte_near(noteptr + i);
  }

 if (prog&3 == PARAM_HARMONIC) ntes[6] = NOTE_GS3; // Sharp seventh

  notePlayer[0].begin(2);
  notePlayer[1].begin(3);
  notePlayer[2].begin(4);
  notePlayer[3].begin(5);
  notePlayer[4].begin(6);
  notePlayer[5].begin(7);
}

unsigned int getValue()
{
int value = 0;
byte i;
     for (i=0; i<6; i++)
      {
        if (analogRead(note[i]) > 200)
        {
		value = value | (1<<i);
		notes[i] = 1;
        }
	else
	{
		notes[i] = 0;
	}
      }
      for (i=6; i<12; i++)
      {
        if (digitalRead(note[i]))
        {
		value = value | (1<<i);
		notes[i] = 1;
        }
	else
	{
		notes[i] = 0;
	}
      }
     return value;
}

/*
 * With the GHC_Piano device positioned over the
 * programming pattern, start the Serial monitor
 * this will restart the Arduino and therefore
 * execute the setup code which reads and then
 * interprets the black/white pattern it sees 
 * as a set of programming parameters for scale,
 * waveform, attack, decay, tremolo, vibrato.
 */

void printParameters(int p)
{
  if ((p&3)==0) Serial.print("Major key ");
  if ((p&3)==1) Serial.print("minor key ");
  if ((p&3)==2) Serial.print("Harmonic minor ");
  if ((p&3)==3) Serial.print("Melodic minor ");
  if ((p>>2)&1) Serial.print("slow attack ");
  else Serial.print("fast attack ");
  if ((p>>3)&1) Serial.print("slow decay ");
  else Serial.print("fast decay ");
  if ((p>>4)&1) Serial.print("vibrato ");
  if ((p>>5)&1) Serial.print("tremolo ");
  Serial.println("");
}

void displayNotes()
{
byte i;
	for(i=0; i<12; i++)
	{
		if (notes[11-i]) Serial.print(" 1");
		else             Serial.print(" 0");
	}
	Serial.println("");
}

void loop()
{
  byte change;
  byte i,j;
  while(1)
  {
      getValue();
      change = 0;
      for(i=0;i<12;i++)
	{
	    if (notes[i] != previous[i])
		{
			change = 1;
			if (notes[i] == 0)
			{
			 for(j=0;j<6;j++)
			 {
				if (busy[j] == i)
				{	
					notePlayer[j].stop();
					busy[j] = 255;
					break;
				}
			 }
			}
			else // Note just starting
			{
			 for(j=0;j<6;j++)
			 {
				if (busy[j] == 255)
				{	
					notePlayer[j].play(ntes[i]);
					busy[j] = i;
					break;
				}
			 }
			}
			previous[i] = notes[i];
		}
	}
      if (change)
      {
        displayNotes();
      }
    }
}
