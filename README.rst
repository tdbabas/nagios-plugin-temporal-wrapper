.. highlight:: perl


****
NAME
****


temporal_wrapper.pl - Wrapper to run different commands for the same Nagios plugin at different times/dates


********
SYNOPSIS
********


\ **temporal_wrapper.pl**\  \ **-c**\  \ *config_file*\ 


***********
DESCRIPTION
***********


\ **temporal_wrapper.pl**\  will read in the \ *config_file*\  and run the first command it encounters which falls within
the current date/time. This plugin was designed such that different thresholds could be set for the same Nagios
check at different times of the day.


************
REQUIREMENTS
************


The following Perl modules are required in order for this script to work:


.. code-block:: perl

  * Getopt::Long
  * POSIX qw(strftime)



*******
OPTIONS
*******


\ **-c**\  \ *config_file*\ , \ **--config**\ =\ *config_file*\ 

Specifies the file containing the list of commands and their associated date/times.


*************************
CONFIG FILE SPECIFICATION
*************************


The config file resembles a crontab file. For each time period in the cron expression, the script will accept a "\*" 
(meaning all values), a single value, a range of values or a comma-separated list of same. For the month and day of
week expressions, the script will also accept capitalised short names e.g. JAN, SEP, WED. An example is shown below:


.. code-block:: perl

  * * * * 3 /usr/lib/nagios/plugins/check_dummy 0 "This is Wednesday"


This will run that particular command every time the Nagios check runs on a Wednesday.


.. code-block:: perl

  * * * * * /usr/lib/nagios/plugins/check_dummy 0 "Run this command by default"


This will run that particular command every time the Nagios check runs.

Note that the script will run the first command it finds with a time period that includes the current date/time. So, 
the ordering of your commands is important. For example, using the examples above, if you placed the default command
above the Wednesday command, the default command will always run - even on a Wednesday. However, if you swapped the
order of these commands, the script will run the Wednesday command on Wednesday, and the default command on every other
day.


***************
ACKNOWLEDGEMENT
***************


This documentation is available as POD and reStructuredText, with the conversion from POD to RST being carried out by \ **pod2rst**\ , which is 
available at http://search.cpan.org/~dowens/Pod-POM-View-Restructured-0.02/bin/pod2rst


******
AUTHOR
******


Tim Barnes <tdba[AT]bas.ac.uk> - British Antarctic Survey, Natural Environmental Research Council, UK


*********************
COPYRIGHT AND LICENSE
*********************


Copyright (C) 2014 by Tim Barnes, British Antarctic Survey, Natural Environmental Research Council, UK

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

