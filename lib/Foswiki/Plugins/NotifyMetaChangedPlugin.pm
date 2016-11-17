# See bottom of file for default license and copyright information
package Foswiki::Plugins::NotifyMetaChangedPlugin;

use strict;
use warnings;

use Foswiki::Func;
use Foswiki::Plugins;

our $VERSION = '1.0';
our $RELEASE = '1.0';
our $SHORTDESCRIPTION = 'Sends mail notifications if a given meta field has changed';
our $NO_PREFS_IN_TOPIC = 1;

our $SITEPREFS = {
  NOTIFYMETACHANGED_APPROVED_ONLY => 1,
  NOTIFYMETACHANGED_MONITORED_FIELDS => 'Responsible',
  NOTIFYMETACHANGED_RECIPIENT_FIELD => 'Responsible',
};

sub initPlugin {
  my ( $topic, $web, $user, $installWeb ) = @_;
  # check for Plugins.pm versions
  if ( $Foswiki::Plugins::VERSION < 2.0 ) {
    Foswiki::Func::writeWarning( 'Version mismatch between ',
    __PACKAGE__, ' and Plugins.pm' );
    return 0;
  }

  return 1;
}

sub afterSaveHandler {
  my ($text, $topic, $web, $error, $meta) = @_;

  my $ctx = Foswiki::Func::getContext();
  my $approvedOnly = Foswiki::Func::getPreferencesValue('NOTIFYMETACHANGED_APPROVED_ONLY');
  my $kvpIsDiscussion = $ctx->{'KVPIsDiscussion'} || 0;
  return if $approvedOnly && $kvpIsDiscussion;

  my $it = $meta->getRevisionHistory();
  my $prevRev;
  for (my $i = 0; $i < 2; $i++) {
    return unless $it->hasNext();
    $prevRev = $it->next();
  }

  my $prevMeta = Foswiki::Meta->load($Foswiki::Plugins::SESSION, $web, $topic, $prevRev);
  my $fields = Foswiki::Func::getPreferencesValue('NOTIFYMETACHANGED_MONITORED_FIELDS');
  my $recipient = Foswiki::Func::getPreferencesValue('NOTIFYMETACHANGED_RECIPIENT_FIELD');
  return unless $recipient;

  my $curRecipient = $meta->get('FIELD', $recipient);
  my $prevRecipient = $prevMeta->get('FIELD', $recipient);
  return unless $curRecipient || $prevRecipient;

  $curRecipient = $curRecipient->{value} || '';
  $prevRecipient = $prevRecipient->{value} || '';
  return unless $curRecipient || $prevRecipient;

  my $formName = $meta->getFormName;
  my $form = Foswiki::Form->new(
    $Foswiki::Plugins::SESSION,
    Foswiki::Func::normalizeWebTopicName($web, $formName)
  );

  my %userFields;
  my (@prevChanged, @curChanged, @changedFields);
  foreach my $fieldName (split(/\s*,\s*/, $fields)) {
    next unless $fieldName;
    my $curField = $meta->get('FIELD', $fieldName);
    my $prevField = $prevMeta->get('FIELD', $fieldName);
    my ($cur, $prev) = '';
    $cur = $curField->{value} if $curField;
    $prev =  $prevField->{value} if $prevField;
    next unless $cur || $prev;
    next if $cur eq $prev;

    push @prevChanged, $prev || '';
    push @curChanged, $cur || '';
    push @changedFields, $fieldName;

    my $ffield = $form->getField($fieldName);
    next unless $ffield;
    $userFields{$fieldName} = 1 if $ffield->{type} =~ /user/;
  }

  my @changes;
  my $cnt = scalar(@prevChanged);
  for (my $i = 0; $i < $cnt; $i++) {
    my $prevChange = $prevChanged[$i];
    my $curChange = $curChanged[$i];
    my $fname = $changedFields[$i];
    if ($userFields{$fname}) {
      $prevChange = $meta->expandMacros("%RENDERUSER{\"$prevChange\" convert=\"on\"}%");
      $curChange = $meta->expandMacros("%RENDERUSER{\"$curChange\" convert=\"on\"}%");
    }

    push @changes, "%MAKETEXT{\"$fname\"}%: $prevChange -> $curChange";
  }
  return unless scalar(@changes);

  my @to = ($curRecipient, $prevRecipient);
  @to = grep {!$_ || $_ =~ /^\s*$/ ? undef : $_} @to;
  Foswiki::Func::setPreferencesValue('METACHANGED_MAIL_TO', join(',', @to));

  my $title = "$web.$topic";
  my $titleField = $meta->get('FIELD', 'TopicTitle');
  $title = $titleField->{value} if $titleField && $titleField->{value};
  Foswiki::Func::setPreferencesValue('METACHANGED_TITLE', "$title");

  my $wikiName = Foswiki::Func::getWikiName();
  my $displayName = $meta->expandMacros("%RENDERUSER{\"$wikiName\" convert=\"on\"}%");
  Foswiki::Func::setPreferencesValue('METACHANGED_ACTOR', $displayName);

  my $link = $meta->expandMacros("%SCRIPTURL{\"view\"}%/$web/$topic");
  Foswiki::Func::setPreferencesValue('METACHANGED_CHANGED_LINK', $link);
  Foswiki::Func::setPreferencesValue('METACHANGED_CHANGED_FIELDS', join("\n", @changes));

  require Foswiki::Contrib::MailTemplatesContrib;
  Foswiki::Contrib::MailTemplatesContrib::sendMail('NotifyMetaChangedMail', {GenerateInAdvance => 1}, {}, 1);
}

1;

__END__
Q.wiki NotifyMetaChangedPlugin - Modell Aachen GmbH

Author: %$AUTHOR%

Copyright (C) 2016 Modell Aachen GmbH

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
