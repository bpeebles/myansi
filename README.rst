######
MyANSI
######

Oh my. This is a piece of my coding past. I got it into my head back in the
1990s--when I was a teenager--that I wanted to write a replacement for ANSI.SYS
that was provided with MS-DOS. There existed other replacements from sources
such as PC Magazine.

It only implements the color and cursor control aspect of ANSI.SYS--no video
mode shifting or keyboard remapping.

To learn about ANSI art (the main reason for this):
http://en.wikipedia.org/wiki/ANSI_art

(Well, the other reason is I wanted my text to scroll faster on a 386 when I
ran `dir` in a large directory, and this gave me that.)

Relased under the MIT license.


Technical details
=================

At the time (MS-DOS 6 era), this was faster than both the default MS-DOS INT
29h handler, that this replaces, and ANSI.SYS. As well as the other ANSI.SYS
replacements I tried out.

It uses something of a finite state machine to handle the different states you
have to be in to correctly parse ANSI control codes.

There's also lots of typos, goofy comments, and goofy code to keep the file
size down.

It's a weird mix of traditional Intel-style Assembly and A86 style Assembly.

Overall, it's a nostalgia piece for me.

Usage
=====

It works under DosBox, which also provide its own ANSI driver so I don't know
the point anymore...

Run::

    myansi

to install. It is a TSR (Terminate and Stay Resident) program.

To uninstall, run::

    myansi u

Reassembling
============

Hopefully it will reassembly with A86? Who knows so I'm including a binary file.
