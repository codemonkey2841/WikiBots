#!/usr/bin/perl

#########################
#
# Filename: RevBot.pl
# Project:  N/A
# Language: Perl
# Platform: Linux
# Summary:  This wiki bot goes through all the application articles and
#           collects revision notes and conglomerates them into one article.
#
#########################
use Config::Simple;
use WikiBot;
use strict;

# Extract the directory where the script lives
$0 =~ /^(.*)RevBot.pl$/;
my $dir = $1;

# Gather variables from config file
Config::Simple->import_from($dir . 'RevBot.ini', \%config);
my $url      = $config{'default.url'};
my $username = $config{'default.username'};
my $passwd   = $config{'default.passwd'};

# Create new bot and log in
my $wiki = new WikiBot('url' => $url, 
                       'username' => $username, 
                       'passwd' => $passwd);
$wiki->login();

# Content of the page
my $content = "[[Category:Applications]]\n\n";
# Get all articles from the Applications category
my @pages = $wiki->getCategory('Applications');

foreach my $title (@pages) {
   # Get the contents of the article
   my $a = $wiki->getArticle($title);
   # Match the article contents with the Application template
   if ($a =~ m/(.*)\|Revisions=\n(.*?)\|(.*)/s) {
      # Split the article contents into pre-revision, revision, and
      #  post-revision
      my $pre = $1;
      my $revs = $2;
      my $post = $3;
      # Create an array of revisions
      my @rev = structRevs($revs);
      # Reformat revision notes in the article
      checkRevs($title, $revs, $pre, $post, @rev);
      $title =~ s/_/ /g;
      $content .= formatRevs($title, @rev);
   }
}
$wiki->setArticle($content, "Official_Supported_Software");
$wiki->logout();

#########################
#
# formatRevs - Formats the revisions list into a section for the wiki article
#
# params
#  title - The title of the article the revisions are from
#  revs  - An array of revisions for the article
#
# returns
#  a string wiki-formatted to be used as a section in the article
#
#########################
sub formatRevs {

   my $title = shift;
   my @revs   = @_;

   # If there are no revisions then return
   if( $#revs < 0 ) {
      return '';
   }
   $content = '==' . $title . '==' . "\n" . 'These are the revisions for the'
      . '[[' . $title . ']] package.' . "\n";

   # Build contents ordered by revision in reverse order
   for( my $x = $#revs; $x >= 0; $x-- ) {
      my $y = "";
      if( $x < 10 ) {
         $y = "0$x";
      } else {
         $y = $x;
      }
      $content .= '===' . $y . '===' . "\n" . 'Package contains:' . "\n" 
         . $revs[$x][0] . "\n" . 'Bugs:' . "\n" . $revs[$x][1] . "\n";
   }
   return $content;

} # end of formatRevs method

#########################
#
# structRevs - Parses the revision notes for an article into an array
#
# params
#  revs - a string of revision notes from an article
#
# returns
#  an array of revision notes delineated by revision number
#
#########################
sub structRevs {

   my $revs = shift;
   # Split revisions by section header
   my @rev = split(/={2,5}\s*(\d+)\s*={2,5}/, $revs);
   my @array;
   my $index = -1;

   foreach (@rev) {
      # Store the information in an array indexed by the revision number
      if ($_ =~ /^(\d+)$/) {
         $index = $1;
      }
      # Store revision notes in the array as (notes, bugs)
      if ($_ =~ /\n(.*?)={2,5}\s*Bugs\s*={2,5}\n(.*)/s) {
         chomp($array[$index][0] = $1);
         chomp($array[$index][1] = $2);
      } elsif (($_ =~ /\n([^=]*)/s) && ($index != -1)) {
         chomp($array[$index][0] = $1);
         chomp($array[$index][1] = "* None Known");
      }
   }

   # Eliminate empty entries in the array
   my $x = 0;
   while ($x < $index) {
      if ($array[$x][0] eq '') {
         for (my $y = $x + 1; $y <= $index; $y++) {
            $array[$y - 1][0] = $array[$y][0];
            $array[$y - 1][1] = $array[$y][1];
         }
         $#array--;
         $index--;
      } else {
         $x++;
      }
   }
   return @array;

} # end of structRevs method

#########################
#
# checkRevs - determines if revision notes are properly formatted and saves
#  formatted revisions to the article
#
# params
#  title - the title of the article to review
#  revs  - a string containing the revision notes for the article
#  pre   - the contents of the article prior to the revision notes
#  post  - the contents of the article after the revision notes
#  rev   - an array of revision notes
#
#########################
sub checkRevs {

   my $title = shift;
   my $revs = shift;
   my $pre = shift;
   my $post = shift;
   my @rev = @_;
   my $content = "";

   # Format the contents of the array into a properly formatted string
   for (my $x = $#rev; $x >= 0; $x--) {
      my $y = "";
      if ($x < 10) {
         $y = "0$x";
      } else {
         $y = $x;
      }
      $content .= "===$y===\n";
      my @i = split(/\n/, $rev[$x][0]);
      foreach (@i) {
         if($rev =~ /\*\s*(.*)/s) {
            $content .= "* $1\n";
         } else {
            $content .= "* $rev\n";
         }
      }
      $content .= "====Bugs====\n";
      @i = split(/\n/, $rev[$x][1]);
      foreach (@i) {
         if($rev =~ /\*{2,}\s*(.*)/s) {
            chomp($content);
            $content .= ", $1\n";
         } elsif($rev =~ /\*\s*(.*)/s) {
            $content .= "* $1\n";
         } else {
            $content .= "* $rev\n";
         }
      }
   }
   $content .= "\n";

   # Match the actual content against the reformatted content
   if ($revs ne $content) {
      # Replace the article contents with the formatted revision
      $content = "$pre\|Revisions=\n$content\|$post";
      $wiki->setArticle($content, $title);
   }

} # end of checkRevs method
