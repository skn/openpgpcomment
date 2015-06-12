# OpenPGPComment MT plugin

# Author - Srijith.K
# Contributions by:
#	- Jacques Distler (http://golem.ph.utexas.edu/~distler/)

# URL - http://www.srijith.net/codes/opengpgcomment/
# (c) - Srijith.K
# License - Perl Artistic License
# Version 1.5
# Last update - 30-Mar-2004 09:36


package MT::Plugin::OpenPGPComment;

use strict;
use MT::Template::Context;
use HTML::Entities;
use CGI;
# Fcntl serves no function other than supress errors
# for non-server-verification folks
# However, it can be useful when using SMDB_File instead
# of DB_File
use Fcntl qw (O_RDONLY O_WRONLY O_CREAT);

use vars qw( $VERSION );
$VERSION = 1.5;

########## GENERIC OPTIONS #########################
# Display raw sig in textarea? Do so for best result.
my $sig_in_textarea=1; 

# Change these values according to your webpage display
my $textarea_rows=20;
my $textarea_cols=60;
########## END OF GENERIC OPTIONS ##################

######### VERIFICATION OPTIONS #####################
# Should this script do server side verifications?
my $do_serverside_verification=0;
# Verification in debug mode.. more verbose output.
# Turn this to 1 if you are performing server side verification to test the process
# Turn it to 0 once you are convinced that all seems to work well.
my $VERIFY_DEBUG=1;

# The path of the keyring for PGP to use by this script
# Please *DO NOT* use your personal GPG/PGP key ring.
# If you starting fresh, create an empty file with this name
# Also create another empty file for backup of the ring file
# OpenPGPComment always creates a backup of the keyring before adding new keys
# Make sure both files are read+writable by the group that the webserver CGI process is a part of
# If in doubt chmod both the files and the directory  to 666.
my $pub_ring='/home/srijith/OPGPC_files/pubring.gpg';
my $pub_ring_backup=$pub_ring.'.bak';

# Database file to associate key_ids and URLs
# *DO NOT* create this file by hand. The script will create it if it does not exist. 
# Just make sure that the dir you want to put this file in is read+writeable by 
# the group that the webserver CGI process is part of 
# If in doubt, chmod the directory to 777 or 666.
my $keyid_url_map_file='/home/srijith/OPGPC_files/keyid_file.db';
########## END OF VERIFICATION OPTIONS ###############


### DO NOT EDIT AFTER THIS, UNLESS YOU ARE A Perl and MT MONKEY ###

# Array that stores the URLs of public keys found in commenter's homepage
my @pubkey_urls=();

MT::Template::Context->add_container_tag('IfSpecificComment' => sub{&showSpecificComment;});
MT::Template::Context->add_container_tag('IfCommentVerification' => sub{&showOnlyThisComment;});
MT::Template::Context->add_container_tag('IfNotSpecificComment' => sub{&showCommentForm;});
MT::Template::Context->add_tag('PGPCommentBody' => sub{&_hdlr_pgpcomment_body;});
MT::Template::Context->add_tag('PGPCommentPreviewBody' => sub{&_hdlr_pgpcomment_body;});
MT::Template::Context->add_conditional_tag('IfPGPSigned' => sub {&ifPGPSigned;});


# Handles the <MTPGPComment> tag
# Scenarios:
#	- Show non PGP comment in comment listing template, after HTML formtatting
#	- If setup, verification is also done.
#	- Show PGP comment (without signature) in comment listing template after HTML formatting
#	- Show raw signed PGP comment without HTML format, in comment listing template

sub _hdlr_pgpcomment_body {
	my($ctx, $args) = @_;
	MT::Template::Context::sanitize_on($args);
	my $tag = $ctx->stash('tag');

	# Before we call sanitize, we should include textarea in the list of
	# allowed tags since we use textarea to display the raw sigature
	# However do this only if it is not the Preview mode. 
	# Else commenter can sneak in a textarea in his comments 
	# Also include 'title' for a href tag
	my $mgr=MT::ConfigMgr->instance;
	my $new_sanitizespec=$mgr->GlobalSanitizeSpec.',a href title';
	if ($sig_in_textarea && ($tag !~ /Preview/)) {
		$new_sanitizespec .=',textarea rows cols';
	}
	$mgr->GlobalSanitizeSpec($new_sanitizespec);


	my $comment = $ctx->stash($tag =~ /Preview/ ? 'comment_preview' : 'comment')
	    or return $ctx->_no_comment_error('MT' . $tag);
	my $blog = $ctx->stash('blog');
	my $comment_text = defined $comment->text ? $comment->text : '';
	$comment_text = MT::Template::Context::munge_comment($comment_text, $blog);
	my $comment_id=$comment->id;
	my $comment_author=$comment->author;
	my $comment_date=MT::Util::format_ts("%H:%M %m/%d/%Y",$comment->created_on);
	my $comment_entry_id=$comment->entry_id;
	my $comment_url=$comment->url;

	my $q = CGI->new;
	my $passed_comment_id=$q->param('comment_id');
	if (!$passed_comment_id) {$passed_comment_id=-1;}
	my $passed_entry_id=$q->param('entry_id');
        if (!$passed_entry_id) {$passed_entry_id=-1;}
	my $raw_pgp=$q->param('raw_pgp');
	if(!$raw_pgp) {$raw_pgp=0;}

	my $string=$comment_text;
	# Comment listing of PGP signed comment 
	# Remove the header and signature and insert link to raw content
	# Note we use the HTML formatted comment_text for display
	if (($string =~ /-----BEGIN PGP SIGNED MESSAGE/) && ($raw_pgp !=1)) {
		my ($head, $sig_text, $sig) = $string =~
			m!-----BEGIN [^\n\-]+-----(.*?\r?\n\r?\n)?(.+)(-----BEGIN.*?END.*?-----)!s;
		$comment->text($sig_text); # temporarily assignment...
		# The call to _hdlr_comment_body is delayed till here to pevent other plugins
		# from messing up with the comment text
		$string = MT::Template::Context::_hdlr_comment_body($ctx, $args);
		# Not exactly required, but let us play safe by putting back the data
		$comment->text($comment_text);
	}
	# Show raw PGP content. Note we are using $comment_text and not $string
	elsif (($comment_text =~ /-----BEGIN PGP SIGNED MESSAGE/) && ($raw_pgp ==1) && ($passed_comment_id == $comment_id) && ($passed_entry_id=$comment_entry_id) && ($sig_in_textarea)) {
		if ($do_serverside_verification) {
			$string=pgp_verify($comment_text,$comment_url);
		}
		else {
			$string='';
		}
		$string .="<textarea rows=\"$textarea_rows\" cols=\"$textarea_cols\">".encode_entities($comment_text)."</textarea><br />OpenPGP signed comment. Back to <a href=\"javascript:history.back()\">plain view</a>.<br /><br />";
	}
	# Do not display anything for other comments when a specific raw comment is being displayed
	elsif ($passed_comment_id > 0 && $passed_comment_id != $comment_id) {
		$string='';
	}
	else {
		# Note that for a non-PGP signed text, the value returned will be the HTML formatted text
		#$ctx->stash('pgp_signed',0);
		$string=MT::Template::Context::_hdlr_comment_body($ctx,$args);
	}
	return $string;

}


# Return 1 if the comment being processed is PGP signed
# 0 is returned otherwise. New in v1.5
sub ifPGPSigned {
	my $ctx = shift;	
	my $pgp_signed=0;	
	my $comment_text = $ctx->stash('comment')->text;
	my $q = CGI->new;
        my $raw_pgp=$q->param('raw_pgp');
        if(!$raw_pgp) {$raw_pgp=0;}
	# The additional check for $raw_pgp is to that the link is
	# not printed when we are already in the raw mode 
	if (($comment_text =~ /-----BEGIN PGP SIGNED MESSAGE/) && ($raw_pgp !=1)) {
		$pgp_signed=1;
	}
	return $pgp_signed;
}


# Container for use when either comment_id is not passed or if passed, equals actual comment_id
# example usage - hide HTML/CSS contents of other comments when listing the raw content of a single comment
sub showSpecificComment {
        my ($ctx, $cond) = @_;
        my $comment = $ctx->stash('comment');
        my $comment_id=$comment->id;
        my $tag = $ctx->stash('tag');
        my $builder = $ctx->stash('builder');
        my $tok = $ctx->stash('tokens');

        my $q=new CGI;
        my $text;
        my $passed_comment_id=$q->param('comment_id');
	if (!$passed_comment_id) {$passed_comment_id=-1;}
        if ($passed_comment_id < 0 || $passed_comment_id == $comment_id) {
                defined($text = $builder->build($ctx, $tok, $cond))
                        || return $ctx->error($ctx->errstr);
        }
        else {
                $text ='';
        }

        return $text;
}
 
# Show this stuff if called with a specific comment_id
sub showOnlyThisComment {
        my ($ctx, $cond) = @_;
        my $tag = $ctx->stash('tag');
        my $builder = $ctx->stash('builder');
        my $tok = $ctx->stash('tokens');

        my $q=new CGI;
        my $text;
        my $passed_comment_id=$q->param('comment_id');
        if ($passed_comment_id)  {
                defined($text = $builder->build($ctx, $tok, $cond))
                        || return $ctx->error($ctx->errstr);
        }
        else {
                $text ='';
        }

        return $text;
}


# Used to show content only when a comment_id is not requested.
# If comment_id param is present, content is not shown
# example usage - hide the comment form when showing raw content of single form
sub showCommentForm {
        my ($ctx, $cond) = @_;
        my $tag = $ctx->stash('tag');
        my $builder = $ctx->stash('builder');
        my $tok = $ctx->stash('tokens');

        my $q=new CGI;
        my $text;
        my $passed_comment_id=$q->param('comment_id');
        if (!$passed_comment_id) {
                defined($text = $builder->build($ctx, $tok, $cond))
                        || return $ctx->error($ctx->errstr);
        }
        else {
                $text ='';
        }

        return $text;
}

# The comment verification function. 
sub pgp_verify {
	require Crypt::OpenPGP;
	require DB_File; 
	my ($string,$homepage_url)=@_;
	my $result='';
	my $pub_key='';
	
	my $msg=Crypt::OpenPGP::Message->new (Data=>$string);
	my @pieces=$msg->pieces;
	my ($sig,$sig_text)=@pieces[0,1];
	my $key_id=$sig->key_id;
	
	my $ring = Crypt::OpenPGP::KeyRing->new( Filename => $pub_ring) or return "Could not find the key-ring $pub_ring<br />";
	if ($ring->find_keyblock_by_keyid($key_id)) {
		$result.="Key already in ring.<br />" if $VERIFY_DEBUG;
	}
	else {
		$result.="Key not in ring. Fetching... <br />\n" if $VERIFY_DEBUG;
	}

	# Fetch the public key only if it does not exists in the ring already
	unless ($ring && ($ring->find_keyblock_by_keyid($key_id))) {
		$result.="Going to find author's  pubkey URL from his homepage $homepage_url<br />\n" if $VERIFY_DEBUG;
		find_pubkey_url($homepage_url);
		for (@pubkey_urls) {
			$result.="Going to get the public key from $_<br />\n" if $VERIFY_DEBUG;
			#If key is not in the keyring already,get and add
		  	my $temp_res=find_key_fromurl($_,$homepage_url,$key_id);
			$result .= "$temp_res<br />" if $VERIFY_DEBUG;
			# If key has already been found, don't loop anymore
			if (index('Successfully added new key_id',$temp_res)>=0) {
				last;
			}
		}
	}
	
	my $pgp = Crypt::OpenPGP->new( PubRing => $pub_ring);
  	my $res = $pgp->handle( Data => $string );
  	if ($res->{Validity}) {
  		#convert key_id to uppercase, hexadecimal format
		my $verified_keyid=uc(unpack('H*', $res->{Signature}->key_id));	
    		$result .= "<p><strong>Good signature</strong> from \"". encode_entities($res->{Validity}). "\"! <br />".
          	"Signed on ". scalar localtime($res->{Signature}->timestamp).
          	" using key ID ". substr($verified_keyid, -8). ".";
		# Look the key up in the database, and recover URL from which it was fetched
		my $verified_homepageurl='';
		tie (my %db, 'DB_File', $keyid_url_map_file,O_RDONLY);
		$verified_homepageurl = $db{$verified_keyid};
		untie %db;
		$result .= "<br />Public-key fetched from <a href=\"$verified_homepageurl\">$verified_homepageurl</a> .</p>\n";
    		return $result;
  	} else {
    		return "$result<p><strong>Bad signature!</strong><br />\n".$pgp->errstr.".</p>\n";
  	}
}

# Find the public key's URL as advertised in the commenter's URL
sub find_pubkey_url {
	require LWP::UserAgent;
	require HTTP::Request;
	require URI::URL;
	my $homepage_url = shift;
	my $ua= LWP::UserAgent->new;
	$ua->agent("OpenPGPComment $VERSION");
	my $req = HTTP::Request->new(GET => $homepage_url );
	my $res = $ua->request($req);
	my $base = $res->base;

	if ($res->is_success) {
		my $content = $res->content();
		#Parse the HTMl to get the PGP key URL
 		my $parser = HTML::Parser->new(start_h => [\&find_pgpurl, 'tagname,attr, attrseq']);
		$parser->report_tags( ('link') );
  		$parser->parse($content);
		# Expand all link URLs to absolute ones
		@pubkey_urls = map { $_ = URI::URL::url($_, $base)->abs; } @pubkey_urls;
	}
}

# Parser code to find 'pgp-keys' URL
sub find_pgpurl {
	require HTML::Parser;
	require URI::URL;
	my ($tag, $attr, $attrseq) = @_;
	foreach (@$attrseq) {
		if (index($_ ,'type')>=0 &&index($attr->{$_},'application/pgp-keys')>=0) {
			my $url= $attr->{'href'};
			push (@pubkey_urls, $url);
			last;
		}
	}
}

# Fetch the public key from all  retrieved URLs and 
# Add the public-key having  the key_id we require, to the ring 
sub find_key_fromurl {
	require LWP::UserAgent;
	require HTTP::Request;
	require Crypt::OpenPGP;
	require File::Copy;
	require DB_File;
 
	my ($pgp_url,$homepage_url,$key_id)=@_;
	my $ua1= LWP::UserAgent->new;
	$ua1->agent("OpenPGPComment $VERSION");
	my $req1 = HTTP::Request->new(GET => $pgp_url);
	my $res1 = $ua1->request($req1);
	my $page = $res1->content;
	# Read any and all keyblocks in the fetched page
	# We assume that the page is an ascii armoured file and contains only PGP/GPG data 
	my $new_key = Crypt::OpenPGP::KeyRing->new( Data => $page )
		or return Crypt::OpenPGP::KeyRing->errstr;
	
	# Proceed only if the key_id used to sign the comment is found in the public-key
	my $kb = $new_key->find_keyblock_by_keyid($key_id);
	if (!$kb) { 
		return "Key $key_id not found in this keyfile. Keyring add unsuccessful.<br />"; 
	}
		
	my $new_key_id=$kb->key->key_id_hex;
	
	# Make a backup of the keyring
	File::Copy::copy ($pub_ring, $pub_ring_backup) 
		or return "Failed to make a backup keyring to $pub_ring_backup";
		
	# save key_id and associated homepage URL to a database
	# If it cannot be saved, abort...
	tie (my %db, 'DB_File', $keyid_url_map_file,O_WRONLY|O_CREAT) 
		or return "Can't open key-url DB file $keyid_url_map_file: $!" ;
	$db{$new_key_id} = $homepage_url;
	untie %db;

	# Read the present ring , add new key to the ring and 
	# write the new ring into the old file	
	# Done after the rest, to prevent situation where key is added and saved 
	# but ring backup or key-url map file update fails.
	my $ring = Crypt::OpenPGP::KeyRing->new( Filename=>$pub_ring )
	       	or return Crypt::OpenPGP::KeyRing->errstr;
	$ring->read;    ## Read in the full keyring.
	$ring->add($kb) or return Crypt::OpenPGP::KeyRing->errstr;
	open FH, ">$pub_ring" or return "Error opening keyring $pub_ring: $!";
	flock(FH,2);
	binmode FH;
	print FH $ring->save;
	close FH;

	return "Successfully added new key_id $new_key_id<br />";
}
