#!/usr/local/bin/perl -w

################################################################################
# temporal_wrapper.pl
#
# Wrapper to run different commands for the same Nagios plugin at different 
# times/dates i.e. to set different thresholds
#
# TDBA 2014-12-03 - First version
# TDBA 2014-12-09 - Replaced XML config file with cron-like config file
################################################################################
# GLOBAL DECLARATIONS
################################################################################
use warnings;
use strict;
use Getopt::Long;
use POSIX qw(strftime);

# Initialise arrays of months and days
my $MONTHS = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"];
my $DAYS   = ["SUN","MON","TUE","WED","THU","FRI","SAT"];
################################################################################
# MAIN BODY
################################################################################

# Get command line arguments
my ($config_file) = (undef);
GetOptions("config|c=s" => \$config_file);

# Check if config file is set and quit if it isn't
if (!defined($config_file)) { die("Config file not specified"); }

# Check if specified config file exists and quit if it doesn't
if (! -e $config_file) { die(sprintf("Config file '%s' does not exist", $config_file)); }

# Get the current date/time
my ($ny, $nm, $nd, $nh, $nn, $ns, $nw) = split(" ", strftime("%Y %m %d %H %M %S %w", localtime()));

# Open the config file
open(FILE, $config_file) or die(sprintf("Cannot open '%s' for reading!", $config_file));

# Go through each line in the file and find the first command that covers the current date/time
my $command = undef;
while (my $line = <FILE>)
{
   chomp $line;

   # If this line is commented out, ignore it
   if ($line =~ m/^#/) { next; }

   # Split the line up 
   my @lineparts = split(" ", $line);

   # Initialise the "in_range" flag
   my $in_range = 0;

   # Parse each temporal component of the line
   for (my $i=0; $i<5; $i++)
   {
       # Split up this component into it's separate parts
       my @cparts = split(",", $lineparts[$i]);

       # Loop through each part of this temporal component
       foreach my $cpart (@cparts)
       {
           # Initialise the "valid" flag
           my $valid = 0;

           # If component contains a single "*", then that is valid and it is also within range
           if (($cpart eq "*") && (scalar(@cparts) == 1)) { $valid = 1; $in_range = 1; }

           # If component is numerical, check it is a valid value and it is within range
           if ($cpart =~ m/^(\d{1,2})$/)
           {
              if ($i == 0) { ($valid, $in_range) = check_validity_and_range([$1], 0, 59, 1, $nn); }
              if ($i == 1) { ($valid, $in_range) = check_validity_and_range([$1], 0, 23, 1, $nh); }
              if ($i == 2) { ($valid, $in_range) = check_validity_and_range([$1], 1, 31, 1, $nd); }
              if ($i == 3) { ($valid, $in_range) = check_validity_and_range([$1], 1, 12, 1, $nm); }
              if ($i == 4) { ($valid, $in_range) = check_validity_and_range([$1], 0,  6, 1, $nw); }
           }

           # If component is a range, check the range is valid and that the time is within that range
           if ($cpart =~ m/^(\d{1,2})\-(\d{1,2})$/)
           {
              if ($i == 0) { ($valid, $in_range) = check_validity_and_range([$1, $2], 0, 59, 1, $nn); }
              if ($i == 1) { ($valid, $in_range) = check_validity_and_range([$1, $2], 0, 23, 1, $nh); }
              if ($i == 2) { ($valid, $in_range) = check_validity_and_range([$1, $2], 1, 31, 1, $nd); }
              if ($i == 3) { ($valid, $in_range) = check_validity_and_range([$1, $2], 1, 12, 1, $nm); }
              if ($i == 4) { ($valid, $in_range) = check_validity_and_range([$1, $2], 0,  6, 1, $nw); }
           }

           # If component is a text string, check it is valid and within range
           if ($cpart =~ m/^([A-Z]{3})$/)
           {
              if ($i == 3) { ($valid, $in_range) = check_text_validity_and_range([$1], $MONTHS, $nm, 1); }
              if ($i == 4) { ($valid, $in_range) = check_text_validity_and_range([$1],   $DAYS, $nw, 0); }
           }

           # If component is a range of text strings, check the range is valid and that the time is within that range
           if ($cpart =~ m/^([A-Z]{3})\-([A-Z]{3})$/)
           {
              if ($i == 3) { ($valid, $in_range) = check_text_validity_and_range([$1, $2], $MONTHS, $nm, 1); }
              if ($i == 4) { ($valid, $in_range) = check_text_validity_and_range([$1, $2],   $DAYS, $nw, 0); }
           }

           # If not valid, display error message and quit
           if (!$valid) { die(sprintf("Malformed config line found: %s", $line)); }
       }

       # If current time is not within the range of this component, then exit this loop prematurely
       if (!$in_range) { last; }
   }

   # If line is within range, then get the command and end the loop
   if ($in_range)
   {
      my $cmd = [];
      for (my $i=5; $i<scalar(@lineparts); $i++) { push(@$cmd, $lineparts[$i]); }
      $command = join(" ", @$cmd);
      last;
   }
}

# Close the config file
close(FILE);

# Run the command, if one has been found. Otherwise, display error message and quit
if (defined($command)) { exec($command); }
else { die("Unable to determine a command"); }
#################################################################################
# SUBROUTINES
################################################################################
sub check_validity_and_range # Checks if value is valid and is within range
{
    my ($vals, $s, $e, $inc, $now) = @_;
    my ($valid, $in_range) = (0, 0);

    foreach my $v (@$vals)
    {
       # Check values are valid
       if (($inc)  && ($s <= $v) && ($v <= $e)) { $valid = 1; }
       if ((!$inc) && ($s <  $v) && ($v <  $e)) { $valid = 1; }
    }

    # If more than one value passed and the first value is greater than the second, it is not valid
    if ((scalar(@$vals) == 2) && (${$vals}[0] > ${$vals}[1])) { $valid = 0; }

    # Check if the current time falls within the range of values
    if ((scalar(@$vals) == 1) && ($now == ${$vals}[0])) { $in_range = 1; }
    if ((scalar(@$vals) == 2) && (${$vals}[0] <= $now) && ($now <= ${$vals}[1])) { $in_range = 1; }

    # Return results
    return ($valid, $in_range);
}
################################################################################
sub check_text_validity_and_range # Checks if text values are valued and within range
{
    my ($vals, $allowed, $now, $diff) = @_;
    my ($valid, $in_range) = (0, 0);
   
    # Get the numerical equivalents of the values
    my $num_vals = [];
    foreach my $v (@$vals)
    {
       my $found = 0;
       for (my $x=0; $x<scalar(@$allowed); $x++)
       {
           if (${$allowed}[$x] eq $v) { $found = 1; $valid = 1; push(@$num_vals, $x); last; }
       }
 
       # If numerical equivalents cannot be found, then exit this subroutine early, since the values are not valid
       if (!$found) { return (0, 0); }
    }

    # Now check the validity and range as normal
    ($valid, $in_range) = check_validity_and_range($num_vals, 0, scalar(@$allowed), 1, $now - $diff);

    # Return results
    return ($valid, $in_range);
}
################################################################################
# DOCUMENTATION
################################################################################

=head1 NAME

temporal_wrapper.pl - Wrapper to run different commands for the same Nagios plugin at different times/dates

=head1 SYNOPSIS

B<temporal_wrapper.pl> B<-c> I<config_file>

=head1 DESCRIPTION

B<temporal_wrapper.pl> will read in the I<config_file> and run the first command it encounters which falls within
the current date/time. This plugin was designed such that different thresholds could be set for the same Nagios
check at different times of the day.

=head1 REQUIREMENTS

The following Perl modules are required in order for this script to work:

 * Getopt::Long
 * POSIX qw(strftime)

=head1 OPTIONS

B<-c> I<config_file>, B<--config>=I<config_file>

Specifies the file containing the list of commands and their associated date/times.

=head1 CONFIG FILE SPECIFICATION

The config file resembles a crontab file. For each time period in the cron expression, the script will accept a "*" 
(meaning all values), a single value, a range of values or a comma-separated list of same. For the month and day of
week expressions, the script will also accept capitalised short names e.g. JAN, SEP, WED. An example is shown below:

 * * * * 3 /usr/lib/nagios/plugins/check_dummy 0 "This is Wednesday"

This will run that particular command every time the Nagios check runs on a Wednesday.

 * * * * * /usr/lib/nagios/plugins/check_dummy 0 "Run this command by default"

This will run that particular command every time the Nagios check runs.

Note that the script will run the first command it finds with a time period that includes the current date/time. So, 
the ordering of your commands is important. For example, using the examples above, if you placed the default command
above the Wednesday command, the default command will always run - even on a Wednesday. However, if you swapped the
order of these commands, the script will run the Wednesday command on Wednesday, and the default command on every other
day.

=head1 ACKNOWLEDGEMENT

This documentation is available as POD and reStructuredText, with the conversion from POD to RST being carried out by B<pod2rst>, which is 
available at http://search.cpan.org/~dowens/Pod-POM-View-Restructured-0.02/bin/pod2rst

=head1 AUTHOR

Tim Barnes E<lt>tdba[AT]bas.ac.ukE<gt> - British Antarctic Survey, Natural Environmental Research Council, UK

=head1 COPYRIGHT AND LICENSE

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

=cut
