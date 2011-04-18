# Piano Player

---------------------  NAME CHANGE EXPLANATION  ---

Arduino (Processing) Development Environment requires the main
source file name and directory name match, and also does not
allow hyphens in sketch file names.  Thus, it was necessary to
change Alan's initial Repository/file from  GHC-piano/piano.pde 
to GHC_piano/GHC_piano.pde

Now it is possible to say:

$ git clone git@github.com:splatspace/GHC_piano.git
$ arduino
   ... and open the sketch "GHC_piano/GHC_piano.pde"

-----------------------------------------------

Authors: Peter Reintjes, Alan Dilpert

Extensively modified from code by:
 Martin Nawrath, Kunsthochschule fuer Medien Koeln (Academy of Media Arts Cologne)

For project information and updates,
please see [its page on the Splat Space wiki](http://wiki.splatspace.org/index.php/Piano).

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

