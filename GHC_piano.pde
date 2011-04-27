/*
 * Direct Digital Synthesis (DDS) Sine Generator
 * Timer2 generates the  31250 KHz Clock Interrupt
 *
 * KHM 2009 / Martin Nawrath, Academy of Media Arts Cologne
 */

#include "avr/pgmspace.h"
#define PARAM_SLOW_ATTACK  3
#define PARAM_SLOW_DECAY   4

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

byte attack[16];
byte decay[16];

#define  ENV 15
int env[] = {  0,0,0,0,0,0,0,0,0,0,0,0,0 };


// The following two tables map Input pins to corresponding musical notes.
//
// index =  0 -> note[0] => input pin 2
//               freq[0] => 220.0 Hz    A 
// index =  1 -> note[1] => input pin 3
//               freq[1] => 233.0 Hz    A#

// Table of notes that the device can play.

double freq[] = {
    220.0, 233.0, 247.0, 260.0, 276.0, 292.0,
    310.0, 328.0, 348.0, 368.0, 391.0, 414.0,
    440.0, 480.0, 520.0 };

#define cbi(sfr, bit) (_SFR_BYTE(sfr) &= ~_BV(bit))
#define sbi(sfr, bit) (_SFR_BYTE(sfr) |= _BV(bit))

byte bb;

double dfreq[5] = { 220.0, 276.0, 328.0, 414.0, 0.0}; // Maj7th chord

byte notes[12];
byte previous[12];

// const double refclk=31372.549;  // =16MHz / 510
const double refclk=31376.6;      // measured

// Variables used inside interrupt service declared as volatile

volatile byte icnt;              // var inside interrupt
volatile byte icnt1;             // var inside interrupt
volatile byte c4ms;              // counter incremented all 4ms

byte k;
unsigned long mix;
unsigned long divx;

volatile unsigned long phaccu[12];   // phase accumulators
volatile unsigned long tword_m[12];  // dds tuning words m

// Table of input pin assignments:
//  The first ten are digital Inputs, skipping over 11
//  The last two, note[10-11] are analog inputs
int    note[] = { 2,3,4,5,6,7,8,9,10,12,0,1 };

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

  Setup_timer2();

  // disable interrupts to avoid timing distortion
  // disable Timer0 !!! delay() is now not available
  cbi (TIMSK0,TOIE0);  

  for(i=0;i<12;i++)
  {
    tword_m[i] = pow(2,32)*freq[i]/refclk; // calulate DDS new tuning words
  }

  delay(300);
  printParameters(getValue());
  /*
   * We fill the RAM attack and decay tables from the 
   * ROM fast/slow-attack/decay tables selected by the
   * pattern seen by the device when it powers up. The
   * first three bits select
   * The binary black/white pattern appears in the "notes" 
   * array, but just this once (on start up), we interpret
   * the bits as a 12-bit programming word. One bit for
   * the fast(default) or slow attack and one bit for the
   * fast(default) or slow decay.
   *
   * The printParameters() routine documents the interpretation
   * of the twelve inputs.
   */
  for(i=0;i<16;i++)
    {
      if ( notes[PARAM_SLOW_ATTACK]) { attack[i]=slow_attack[i];   }
      else                           { attack[i] = fast_attack[i]; }
      if ( notes[PARAM_SLOW_DECAY])  { decay[i] = slow_decay[i];   }
      else                           { decay[i] = fast_decay[i];   }
    }

  sbi (TIMSK2,TOIE2);              // enable Timer2 Interrupt
}

unsigned int getValue()
{
int value = 0;
byte i;
      for (i=0; i<10; i++)
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
     for (i=10; i<12; i++)
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
  byte i;
  while(1) {
     if (c4ms > 50) {                 // timer / wait a full second
      c4ms=0;
      getValue();

       /*
       * To avoid producing a click every time we check the inputs, we
       * update the interrupt routine data only when a note has changed.
       */
      change = 0;
      for(i=0;i<12;i++)
	{
	    if (notes[i] != previous[i]) 
		{
			change = 1;
			previous[i] = notes[i];
		}
	}

      if (change)
      {
        displayNotes();
//      cbi (TIMSK2,TOIE2);              // disble Timer2 Interrupt
//      sbi (TIMSK2,TOIE2);              // enable Timer2 Interrupt 
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
// (Peter has added a lot of code, we have no idea
// how many instructions we're executing now, but 
//
// We can't spend more than 31 microseconds in this
// (four times more code than Martin Nawrath had originally)
// routine without slowing down the sample rate (32kHz)
//

ISR(TIMER2_OVF_vect)
{
  divx = 1;
  /*
   * divx was called div, but there is some kind of
   * weird arduino built-in that got broken! It is 
   * the value we need to divide by when we add more
   * than one note (data from the sine table) and must
   * scale it down to avoid distortion.
   */

  mix = 0;
  /*
   * mix is the accumulator for the amplitude of the combined
   * sine waves at this instant.
   */

  /*
   * We've got no business looking at all twelve notes since
   * we're not going to play more than four at once, so 
   * we should have a four element structure here and just
   * see what four (or less) notes are playing.
   *  Ben? 
   */

  for (k=0; k<12; k++)   // For each of the twelve notes
    {
      if (notes[k])   // This note is playing 
	{
	     phaccu[k] = phaccu[k] + tword_m[k];
	     icnt = phaccu[k] >> 24;
	     mix += pgm_read_byte_near(sine256 + icnt); // << attack[env[k]];
	    // if (env[k]>1) { divx += env[k]; }
              divx++;
	     if (env[k]) { env[k]--; } // Don't decrement below zero
	}
       /* Look below for a version with an "else" here.
        * this "else" is for the decay of a note that is
        * no longer playing. But then, this code would be
        * executed for all the notes that aren't playing
        * whether they are really decaying from previous 
        * playing or not.
        * But this would be okay because their "envelope" value
        * would point at the zeroth element of the decay 
        * table which would effectively drive it to zero.
        */
    }
    /*
     * I'm struggling with finding the right value of divx
     * It can't be zero because we want to divide by it, so I
     * set it to 1 when I started, but now it has been increased
     * for each "additional" note. But that means that a single
     * note has incremented it to 2, so we adjust it down by one
     * while making sure we don't reduce it to zero.
     */
    if (divx > 1) divx--;

    /*
     * You can print debug info from inside an interrupt routine,
     * if you really want to see what is going on, but it has no
     * chance of creating any sound that makes much sense.
     *
     * So, once the data looks right, you must comment out
     * the print statements to listen to the real thing.
     */
/*
 
    Serial.print("divider ");
    Serial.print(divx);
    Serial.print(" mix ");
    Serial.print(mix);
    Serial.print(" b ");
    Serial.println((int)b);
*/
    byte b = mix/divx;
    OCR2A = b;

/*  The version below (which doesn't work yet) attempts to scale up notes
 * via the attack table and scale down with the decay table
 * by indexing along with the envelope value.
 * To start a note, set the envelope value at 15.
 * As the note begins, it will grab the attack value from attack[15]
 * and use this to shift the value up (louder) according to the 
 * values in the attack array -- the interrupt routine will decrement
 * the envelope pointer for this note from 15 down to zero on
 * some reasonable schedule -- not every interrupt but maybe every 
 * forth interrupt.
 * When the note is not longer playing (note[n] zero) we set the
 * envelope counter to 15 again, and this time it decrements through
 * the decay array.  Shifting right this time to diminish the volume.
 */

/*

  for (k=0; k<12; k++)
    {
      phaccu[k] = phaccu[k] + tword_m[k]; // soft DDS, 32-bit phase info
      icnt = phaccu[k] >> 24;             // upper 8 bits of  phase 

      // read value from ROM sine table and scale
      if (notes[k])
	{
	  mix += pgm_read_byte_near(sine256 + icnt) << attack[env[k]];
	  if (env[k]>1) { divx += env[k]; }
	}
	else
	{
	  mix += pgm_read_byte_near(sine256 + icnt) >> decay[env[k]];
	  if (decay[env[k]]<2) { divx++; }
	}
	if (env[k]) { env[k]--; } // Don't decrement below zero
	notes = notes>>1;
    }
    mix = pgm_read_byte_near(sine256 + icnt);
    OCR2A = mix/divx;      // send scaled value to PWM DAC
    
*/   

/* NOTE:
 *        OCR2A = mix/divx;  // doesn't seem to work
 *
 *  but
 *
 *        byte b = mix/divx;
 *        OCR2A = b;
 *
 * Does work. So watch out for data types and alignment?
 *
 */

    if( icnt1++ == 80)   // (was 125) increment variable c4ms all 4ms?
      {
	c4ms++;
	icnt1=0;
      }
}
