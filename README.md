# openpgpcomment
This is a placeholder repo for the old OpenPGPComment Movable Typle plugin.
It has been retired for over a decade but is put up here with the hope that 
it might be useful for others, somewhere, sometime.

OpenPGPComment Movable Type plugin
Version 1.5 
Release Date - March 30, 2004
Copyright (c) 2004, Srijith.K
License - Perl Artistic License


Details at http://www.srijith.net/codes/pgpcomment/index.shtml
(now retied)

ACKNOWLEDGMENTS
***************

Originally inspired by - Paul Bausch's system (http://www.onfocus.com/comments.asp?id=3005)
Parsing code - Crypt::OpenPGP Perl module (http://www.stupidfool.org/perl/openpgp/)
Contributions -  Jacques Distler (http://golem.ph.utexas.edu/~distler/)


INSTALL
*******
There is only one file that has to be installed. Unzip the file "OpenPGPComment.pl" 
into the "plugins" directory of your MT installation and chmod it to 755. If you 
plan to enable server-side verification, you will need to setup three other files. 
Details can be found at the project website. 

You can also customise the setup by editing several variables. Again, please
visit the website to read more details.



UPGRADE
*******
- Upgrade from 1.4 - 
Note that as of v1.5, the link to the raw PGP content/verification result of the comment 
has to be inserted by the blog owner in his template design. This gives it more flexibility.
Note the use of the tag 'MTIfPGPSigned' at the project website to see how this can be done.
 
- Upgrading from 1.3 -
Just replace the older OpenPGPComment.pl script with the new one. To play safe, keep 
a backup copy of the old script somewhere. Make sure that the backup copy does not
have '.pl' extension if you save it in the 'plugins' directory. Note the use of the
extra tag 'MTIfPGPSigned'.


- Upgrading from 1.2 -
Additional new tags for more flexibility - 'MTPGPCommentPreviewBody' 'MTIfCommentVerification' 
and ''MTIfPGPSigned'. See project page for usage.

- Upgrading from 1.1 -
If you are upgrading from 1.1, please note that PGPComment="1" is no longer used. Rather
'MTPGPComment' has to be used. Also note that a lot of new tags have been added. Refer 
to project URL for details and example usage.


- Upgrading from 1.0 or 1.01 -
Please note that this plugin was intialy called "PGPComment". As of version 1.1, it will 
be called OpenPGPComment to relfect the underlying specifications. 

Hence, if you have already installed versions 1.0 or 1.01, there will be a file named 'PGPComment.pl' 
in the 'plugins' directory. Please delete it and use the new 'OpenPGPComment.pl' file found in 
the latest version. 

Again, your plugin directory should not contain the file 'PGPComment.pl'. Only 'OpenPGPComment.pl' 
should be present.

A lot of new tags have been added. Refer to the project homepage to find out how to use the 
new tags.


USAGE
*****
Refer to http://www.srijith.net/codes/openpgpcomment/


Changelog
----------
Version 1.5 (30-March 2004)
    - Added conditional tag 'MTIfPGPSigned' to add flexibility to the way the 
      link to raw PGP comment/verification result is placed within the MT template. (Thanks to
      Jacques Distler for the idea and sample code)
    - Fixed bug that prevented plugin from working with other comment filters like
      MT-Textile. (Thanks to Brad Choate for the fix)

Version 1.4 (10-March-2004)
    - Added support for comment verification at the server
    - Added back link from raw view
    - Hide unnecessary modules from those who don't need server side verification

Version 1.3 (02-Mar-2004)
    - Fixed sanitize security hole
    - Added two new tags for more felxibility
    - Several small fixes

Version 1.2 (27-Feb-2004)
    - Finally got rid (?) of the verification problem due to HTML tags in comment body
    - In the process, introduced 'MTPGPComment' tag instead of the 'PGPComment="1"'

Version 1.1 (26-Feb-2004)
    - Changed plugin name from PGPComment to OpenPGPComment
    - Added support for showing signed comments in text area

Version 1.01 (24-Feb-2004)
    - Added support for no standard location/name for mt-comment script file

Version 1.0 (23-Feb-2004)
    - Intial release
