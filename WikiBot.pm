#########################
#
#  Filename: WikiBot.pm
#  Project:  None
#  Platform: N/A
#  Summary:  A perl module that provides the base functionality to create
#            an automated script for editing articles in a mediawiki 
#            installation.
#
#########################
package WikiBot;

use strict;
use warnings;
use utf8;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Error;
use HTML::Entities;
use LWP;
use XML::Simple;

require Exporter;

@ISA = qw(Exporter AutoLoader);
@EXPORT = qw($VERSION);
$VERSION = '0.01';

my %attr = ();
my $browser;
my $xml;

#########################
#
# new - the constructor method for a WikiBot object
#
# params
#  pkg - The package type of this object (passed by default with new)
#  @_  - A hash of parameters including
#        url      - the url of the wiki
#        username - the user name assigned to the bot in the wiki
#        passwd   - the plaintext password of the user
# 
# returns
#  a newly created WikiBot object
#
#########################
sub new {

   my $pkg = shift;
   $browser = LWP::UserAgent->new;
   push @{ $browser->requests_redirectable }, 'POST';
   $xml = new XML::Simple;
   %attr = @_;
   if (defined($attr{'username'})) {
      if( !isUser($attr{'username'}) ) {
         $attr{'username'} = '';
      }
   }
   return bless ({}, $pkg);

} # end of constructor method

#########################
#
# setUser - Changes the user attribute of the object
#
# params
#  user - The name of the user to use for this object
#
#########################
sub setUser {

   # Empty null variable
   shift;
   $user = shift;
   if (isUser($user)) {
      $attr{'username'} = $user;
   }

} # end of setUser method

#########################
#
# getUser - Returns the user attribute of the object
#
# returns
#  a string containing the user name associated with the object
#
#########################
sub getUser {

   return $attr{'username'};

} # end of getUser method

#########################
#
# setPass - Changes the password attribute of the object
#
# params
#  passwd - The password for the object
#
#########################
sub setPass {

   # Empty null variable
   shift;
   $attr{'passwd'} = shift;

} # end of setPass method

#########################
#
# setURL - Changes the URL attribute of the object
#
# params
#  url - The base url of the wiki installation
#
#########################
sub setURL {

   # Empty null variable
   shift;
   $attr{'url'} = shift;

} # end of setURL method

#########################
#
# getURL - Returns the base url associated with the object
#
# returns
#  a string containing the base url attribute
#
#########################
sub getURL {

   return $attr{'url'};

} # end of the getURL method

#########################
#
# isUser - Determines whether a given user name is a user in the wiki or not
#
# params
#  name - The name of the user to validate
#
# returns
#  1 if user is valid, 0 if invalid
#
#########################
sub isUser {

   my $name = shift;

   # Grab the user list from the wiki
   my $con = _XMLize("http://" . $attr{'url'} . "/index.php/Special:Listusers");
   # Convert XML entity to a string
   $_ = XMLout($con->{body}->{div}->{div}->[0]->{div}->{div}->{ol}->{li});
   # Convert string to an array
   my @res = />(\w*)<\/a/g;
   foreach (@res) {
      # if the current name matches $name then it is valid
      if (lc($_) eq lc($name)) {
         return 1;
      }
   }
   return 0;

} # end of isUser method

#########################
#
# _XMLize - Takes a URL and turns it into an XML entity
#
# params
#  url - The URL of a page to be converted
#
# returns
#  an XML object
#
#########################
sub _XMLize {

   my $url = shift;
   my $response = $browser->get($url)->content;
   $response =~ s/&nbsp\;/&#160\;/gi;
   return $xml->XMLin($response);

} # end of XMLize method

#########################
#
# login - Log the user into the mediawiki installation
#
#########################
sub login {

   if (defined($attr{'url'}) && defined($attr{'username'})) {
      $browser->cookie_jar({});
      my $furl = "http://" . $attr{'url'} . "/index.php?action=submitLogin"
         . "&title=Special:Userlogin";
      # Submit login data to the wiki
      return $browser->post( $furl,
         [
            'wpName'         => $attr{'username'},
            'wpPassword'     => $attr{'passwd'},
            'wpRemember'     => 1,
            'wpLoginattempt' => 'Log In',
         ]
      );
   } else {
      print "User name or site not set\n";
   }

} # end of login method

#########################
#
# logout - Logs the user out of the mediawiki installation
#
#########################
sub logout {

   my $furl = "http://" . $attr{'url'} . "/index.php?title=Special:"
      . "Userlogout";
   $browser->get($furl);

} # end of logout method

#########################
#
# getArticle - Get article contents from the wiki
#
# params
#  article - the article title to retrieve
#
# returns
#  a string containing the entire contents of the article
#
#########################
sub getArticle {

   # Empty null variable 
   shift;
   my $article = shift;
   my $con = _XMLize("http://" . $attr{'url'} . "/index.php/Special:Export/"
      . $article);
   return $con->{page}->{revision}->{text}->{content};

} # end of getArticle method

#########################
#
# setArticle - Set article contents in the wiki
#
# params
#  wpTextbox1 - The new contents of the article
#  article - The title of the article
#
#########################
sub setArticle {

   # Empty null variable
   shift;
   my $wpTextbox1 = shift;
   my $article = shift;
   encode_entities($article);

   # Retrieve the edit page for the specified article
   my $data = _XMLize("http://" . $attr{'url'} . "/index.php?title="
      . $article . "&action=edit");
   $data = $data->{body}->{div}->{div}->[0]->{div}->{div}->{form};

   # Gather values needed to pass back during submission
   my $wpSection = $data->{input}->{wpSection}->{value};
   my $wpSummary = $data->{input}->{wpSummary}->{value};
   my $wpWatchthis = 0;
   my $wpMinoredit = $data->{input}->{wpMinoredit}->{value};
   my $wpEditToken = $data->{input}->{wpEditToken}->{value};
   my $wpEdittime = $data->{input}->{wpEdittime}->{value};
   my $temp = $data->{textarea}->{content};

   # Submit new content to wiki
   if ($wpTextbox1 ne $temp) {
      $browser->post("http://" . $attr{'url'} . "/index.php?title=" . $article 
         . "&action=submit",
         [
            wpSection => $wpSection,
            wpSummary => $wpSummary,
            wpWatchthis => $wpWatchthis,
            wpMinoredit => $wpMinoredit,
            wpEditToken => $wpEditToken,
            wpEdittime => $wpEdittime,
            wpTextbox1 => $wpTextbox1
         ]
      );
   }

} # end of setArticle method

#########################
#
# getAll - Retrieves all articles in a wiki
#
# returns
#  an array of article titles from the wiki
#
#########################
sub getAll {

   # Empty list to store titles in
   my @list;
   # Retrieve contents of the All Pages page
   my $con = _XMLize("http://" . $attr{'url'} . "/index.php/Special:Allpages");
   my $a = $con->{body}->{div}->{div}->[0]->{div}->{div}->{table}->[1]->{tr};
   my $x = 0;

   # For each row of articles listed...
   while (defined($a->[$x])) {
      my $b = $a->[$x]->{td};
      my $y = 0;
      # For each column of articles listed...
      while (defined($b->[$y])) {
         my $c = $b->[$y]->{a}->{title};
         if (defined($c)) {
            $c =~ s/\ /_/gi;
            push(@list, $c);
         }
         $y++;
      }
      $x++;
   }
   return @list;

} # end of getAll method

#########################
#
# getRecent - Get a list of articles that were recently changed
#
# returns
#  an array of article titles
#
#########################
sub getRecent {

   my @list;
   my $con = _XMLize("http://" . $attr{'url'} . "/index.php?title="
      . "Special:Recentchanges&hidepatrolled=0&days=1");
   my $a = $con->{body}->{div}->{div}->[0]->{div}->{div}->{ul};
   my $x = 0;
   eval {
      while (defined($a->[$x])) {
         my $b = $a->[$x]->{li};
         my $y = 0;
         while (defined($b->[$y])) {
            my $c = $b->[$y]->{a}->[0]->{title};
            my $d = 0;
            if ($c =~ /Special.*/) {
               $y++;
               next;
            }
            foreach (@list) {
               if ($c eq $_) {
                  $d = 1;
               }
            }
            if ($d == 0) {
               push(@list, $c);
            }
            $y++;
         }
         $x++;
      }
   };
   if ($@) {
      while (defined($a->[$x])) {
         my $b = $a->[$x]->{a}->[0]->{title};
         my $c = 0;
         if ($b =~ /Special.*/) {
            $x++;
            next;
         }
         foreach (@list) {
            if ($b eq $_) {
               $c = 1;
            }
         }
         if ($c == 0) {
            push(@list, $b);
         }
         $x++;
      }
   }
   return @list;

} # end of getRecent method

#########################
#
# getCategory - Returns a list of articles that are in the specified category
#
# params
#  cat - The category of articles to retrieve
#
# returns
#  an array of article titles in the specified category
#
#########################
sub getCategory {

   # Empty null variable
   shift;
   my @list;
   my $cat = shift;
   
   # Get XML entity of Category listing
   my $con = _XMLize("http://" . $attr{'url'} . "/index.php/Category:" . $cat);
   my $a = $con->{body}->{div}->{div}->[0]->{div}->{div}->{table}->{tr}->{td};
   
   my $x = 0;
   # For each row on the category page
   while (defined($a->[$x])) {
      my $b = $a->[$x]->{ul};
      my $y = 0;
      # For each list in the row
      while (defined($b->[$y])) {
         my $c = $b->[$y]->{li};
         my $z = 0;
         eval {
            # For each item in the list
            while (defined($c->[$z])) {
               my $d = $c->[$z]->{a}->{title};
               $d =~ s/\ /_/gi;
               push(@list, $d);
               $z++;
            }
         };
         if ($@) {
            my $d = $c->{a}->{title};
            $d =~ s/\ /_/gi;
            push(@list, $d);
         }
         $y++;
      }
      $x++;
   }
   return @list;

} # End of getCategory method

1;
__END__
