/*
 * Direct Digital Synthesis (DDS) Sine Generator
 * Timer2 generates the  31250 KHz Clock Interrupt
 *
 * KHM 2009 / Martin Nawrath, Academy of Media Arts Cologne
 */

#include "avr/pgmspace.h"
#define SLOW_ATTACK  0x10
#define SLOW_DECAY   0x20

// 256 element flash memory array of one sinewave cycle

PROGMEM  prog_uchar sine256[]  = {
  127,130,133,136,139,143,146,149, 152,155,158,161,164,167,170,173, //      \
  176,178,181,184,187,190,192,195, 198,200,203,205,208,210,212,215, //       \
  217,219,221,223,225,227,229,231, 233,234,236,238,239,240,242,243, //        \
  244,245,247,248,249,249,250,251, 252,252,253,253,253,254,254,254, //         |
  254,254,254,254,253,253,253,252, 252,251,250,249,249,248,247,245, //         |
  244,243,242,240,239,238,236,234, 233,231,229,227,225,223,221,219, //         /
  217,215,212,210,208,205,203,200, 198,195,192,190,187,184,181,178, //        /
  176,173,170,167,164,161,158,155, 152,149,146,143,139,136,133,130, //       /
  127,124,121,118,115,111,108,105, 102, 99, 96, 93, 90, 87, 84, 81, //      /
   78, 76, 73, 70, 67, 64, 62, 59,  56, 54, 51, 49, 46, 44, 42, 39, //     /
   37, 35, 33, 31, 29, 27, 25, 23,  21, 20, 18, 16, 15, 14, 12, 11, //    /
   10,  9,  7,  6,  5,  5,  4,  3,   2,  2,  1,  1,  1,  0,  0,  0, //   |
    0,  0,  0,  0,  1,  1,  1,  2,   2,  3,  4,  5,  5,  6,  7,  9, //   |
   10, 11, 12, 14, 15, 16, 18, 20,  21, 23, 25, 27, 29, 31, 33, 35, //    \
   37, 39, 42, 44, 46, 49, 51, 54,  56, 59, 62, 64, 67, 70, 73, 76, //     \
   78, 81, 84, 87, 90, 93, 96, 99, 102,105,108,111,115,118,121,124  //
};

/*
 * These numbers are multipliers (shift amounts)
 * to control dynamics.
 */

PROGMEM  prog_uchar fast_attack[] = {  0,1,1,1,1,2,2,2,2,3,3,3,4,4,2,1 };
PROGMEM  prog_uchar slow_attack[] = {  0,1,1,2,2,3,3,3,3,3,2,2,2,1,1,1 };
PROGMEM  prog_uchar fast_decay[]  = {  7,7,7,7,6,6,5,5,4,4,3,3,2,2,1,1 };
PROGMEM  prog_uchar slow_decay[]  = {  7,6,6,5,5,5,4,4,4,3,3,3,2,2,1,1 };

#define  ENV 15
int env[] = {  0,0,0,0,0,0,0,0,0,0,0,0,0 };


// The following two tables map Input pins to corresponding musical notes.
//
// index =  0 -> note[0] => input pin 2
//               freq[0] => 220.0 Hz    A 
// index =  1 -> note[1] => input pin 3
//               freq[1] => 233.0 Hz    A#

// Table of notes that the device can play.

double freq[] = { 220.0, 233.0, 247.0, 260.0, 276.0, 292.0,
                  310.0, 328.0, 348.0, 368.0, 391.0, 414.0, 440.0, 480.0, 520.0 };

#define cbi(sfr, bit) (_SFR_BYTE(sfr) &= ~_BV(bit))
#define sbi(sfr, bit) (_SFR_BYTE(sfr) |= _BV(bit))

byte bb;

double dfreq[5] = { 220.0, 276.0, 328.0, 414.0, 0.0}; // Maj7th chord

// const double refclk=31372.549;  // =16MHz / 510
const double refclk=31376.6;      // measured

// Variables used inside interrupt service declared as volatile

volatile byte icnt;              // var inside interrupt
volatile byte icnt1;             // var inside interrupt
volatile byte c4ms;              // counter incremented all 4ms

volatile unsigned long current;
volatile unsigned long previous;
volatile unsigned long notes;

volatile unsigned long phaccu[12];   // phase accumulators
volatile unsigned long tword_m[12];  // dds tuning words m
volatile unsigned long tword_t[12];  // temp storage
volatile unsigned long attack[16];
volatile unsigned long decay[16];

// Table of input pin assignments:
//  The first ten are digital Inputs, skipping over 11
//  The last two, note[10-11] are analog inputs
int    note[] = { 2,3,4,5,6,7,8,9,10,12,0,1 };

void setup()
{
  pinMode(13, OUTPUT);        // sets the digital pin as output
  Serial.begin(115200);       // connect to the serial port
  Serial.println("GHC");

  for(byte i=0;i<10;i++)
  {
	pinMode(note[i], INPUT);
	digitalWrite(note[i], HIGH);
  }

  Setup_timer2();

  // disable interrupts to avoid timing distortion
  // disable Timer0 !!! delay() is now not available
  cbi (TIMSK0,TOIE0);  

  delay(300);
  int parameters = getValue();
  printParameters(parameters);

  for(byte i=0;i<16;i++)
    {
      if ( parameters & SLOW_ATTACK) { attack[i] = slow_attack[i]; }
      else                           { attack[i] = fast_attack[i]; }
      if ( parameters & SLOW_DECAY)  { decay[i] = slow_decay[i];   }
      else                           { decay[i] = fast_decay[i];   }
    }

  sbi (TIMSK2,TOIE2);              // enable Timer2 Interrupt
}

int getValue()
{
unsigned int value = 0;
byte i;
      for (i=0; i<10; i++)
      {
        if (digitalRead(note[i]))
        {
		value |= 1<<i;
        }
      }
     for (i=10; i<12; i++)
      {
        if (analogRead(note[i]) > 200)
        {
		value |= 1<<i;
        }
      }
     return value;
}

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

void loop()
{
  byte i;
  while(1) {
     if (c4ms > 100) {                 // timer / wait a full second
      c4ms=0;
      current = getValue();

       /*
       * To avoid producing a click every time we check the inputs, we
       * update the interrupt routine data only when a note has changed.
       */

      if (current != previous)
      {
        previous = current;
        for(i=0;i<12;i++)
        {
         tword_t[i] = pow(2,32)*dfreq[i]/refclk;  // calulate DDS new tuning words
        }
        cbi (TIMSK2,TOIE2);              // disble Timer2 Interrupt
        for(i=0;i<12;i++)
	{
	    tword_m[i] = tword_t[i];
        }
        sbi (TIMSK2,TOIE2);              // enable Timer2 Interrupt 
      }
    }
  }
 }

/*
 * timer2 setup
 * prescaler to 1, PWM mode to phase correct PWM, 16000000/510 = 31372.55 Hz clock
 */

void Setup_timer2()
{

// Timer2 Clock Prescaler to : 1
  sbi (TCCR2B, CS20);
  cbi (TCCR2B, CS21);
  cbi (TCCR2B, CS22);

  // Timer2 PWM Mode set to Phase Correct PWM
  cbi (TCCR2A, COM2A0);  // clear Compare Match
  sbi (TCCR2A, COM2A1);

  sbi (TCCR2A, WGM20);  // Mode 1  / Phase Correct PWM
  cbi (TCCR2A, WGM21);
  cbi (TCCR2B, WGM22);
}


//*****************************************************
// Timer2 Interrupt Service at 31372,550 KHz = 32uSec
// this is the timebase REFCLOCK for the DDS generator
// FOUT = (M (REFCLK)) / (2 exp 32)
// runtime : 8 microseconds ( inclusive push and pop)

ISR(TIMER2_OVF_vect)
{
  unsigned long mix = 0;
  byte i = 0;
  unsigned int div = 1;
  notes = current;
  for (byte i=0; i<12; i++)
    {
      phaccu[i] = phaccu[i] + tword_m[i]; // soft DDS, 32-bit phase info
      icnt = phaccu[i] >> 24;             // upper 8 bits of  phase 

      // read value fron ROM sine table and scale
      if (notes&1)
	{
	  mix += pgm_read_byte_near(sine256 + icnt) << attack[env[i]];
	  if (env[i]>1) { div += env[i]; }
	}
	else
	{
	  mix += pgm_read_byte_near(sine256 + icnt) >> decay[env[i]];
	  if (decay[env[i]]<2) { div++; }
	}
	if (env[i]) { env[i]--; } // Don't decrement below zero
	notes = notes>>1;
    }
    OCR2A = mix/div;      // send scaled value to PWM DAC
   
    if( icnt1++ == 100)   // (was 125) increment variable c4ms all 4ms?
      {
	c4ms++;
	icnt1=0;
      }
}
