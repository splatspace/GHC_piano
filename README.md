# Piano Player

Authors: Peter Reintjes, Alan Dilpert

Extensively modified from code by: Martin Nawrath, Kunsthochschule fuer Medien Koeln (Academy of Media Arts Cologne)

For project information and updates, please see [its page on the Splat Space wiki](http://wiki.splatspace.org/index.php/Piano).

Goals:
	12 binary inputs representng an arbitrary musical scale,
	multiple simultaneous notes,
	Variable attack decay, waveform modification for natural sounding tones.

        Scale, range, dynamics, to be selected by creating a binary pattern
        under the reader and pressing the reset button.

        For example, nine of the twelve bits can be used to define
        the following parameters:

        Scale: Major, minor, harmonic minor, melodic minor (two bits)
        Fast/slow attack (one bit)
        Fast/slow decay (one bit)
        Zero, even, odd, all harmonics (sine,triangle,square,sawtooth) (two bits)
        Variable/Fixed Timbre (one bit)
        Variable/Fixed Amplitude (tremolo) (one bit)
        Variable/Fixed Frequency (vibrato) (one bit)


Current: 
	12 binary inputs representing the chromatic scale
        Four simultaneous sine waves (e.g. No dynamics or timbre)

