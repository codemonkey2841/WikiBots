#!/usr/bin/perl

###########################
#
# Filename: servlBot.pl
# Project:  servlBot
# Language: perl
# Platform: Linux
# Summary:  Creeps through a wiki installation looking for server names (as
#           per article names in the Server category) and links them back to
#           the server article.
#
###########################
use Config::Simple;
use WikiBot;
use strict;

# Extract the directory where the script lives
$0 =~ /^(.*)servlBot.pl$/;
my $dir = $1;

# Gather variables from config file
Config::Simple->import_from($dir . 'servlBot.ini', \%config);
my $url      = $config{'default.url'};
my $username = $config{'default.username'};
my $passwd   = $config{'default.passwd'};

# Create new bot and log in
my $wiki = new WikiBot('url' => $url, 
                       'username' => $username, 
                       'passwd' => $passwd);
$wiki->login();

# Get a list of servers from the wiki
my @servs = $wiki->getCategory("Servers");

# Build a search pattern of valid server names
my $pattern = "(";
foreach my $serv (@servs) {
   if ($serv !~ /.*\..*/) {
      next;
   }
   $pattern .= "$serv|";
}
chop($pattern);
$pattern = "([^\[])$pattern)([^\]|^\.])";

my @arts;
# If a command-line argument is present, then search all articles, else
#  recent articles
if ($ARGV[0]) {
   @arts = $wiki->getAll();
} else {
   @arts = $wiki->getRecent();
}

# Search article contents for server names and wikilink them
foreach my $art (@arts) {
   $a = $wiki->getArticle($art);
   $b = $a;
   $b =~ s/$pattern/$1\[\[$2\]\]$3/ig;
   if ($a ne $b) {
      $wiki->setArticle($b, $art);
   }
}
