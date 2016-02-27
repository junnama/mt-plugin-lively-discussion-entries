package LivelyDiscussionEntries::Tags;
use strict;
use warnings;
use MT::Entry;

sub _hdlr_lively_discussion_entries {
    my ( $ctx, $args, $cond ) = @_;
    my $days = $args->{ days } || 7;
    my $lastn = $args->{ lastn };
    my $blog = $ctx->stash( 'blog' );
    my $blog_id = $args->{ blog_id };
    if ( $blog_id ) {
        $blog = MT->model( 'blog' )->load( $blog_id );
    } else {
        $blog_id = $blog->id;
    }
    # my $server_offset = $blog->server_offset;
    # $server_offset = $server_offset * 86400;
    my $epoc = time();
    $epoc = $epoc - $days * 86400;
    my $ts = MT::Util::epoch2ts( $blog, $epoc );
    my $group_iter = MT->model( 'comment' )->count_group_by( {
                                                blog_id => $blog_id,
                                                visible => 1,
                                                created_on => { '>' => $ts } } , {
                                                (),
                                                group => [ 'entry_id' ],} );
    my $ids = {};
    while ( my ( $count, $entry_id ) = $group_iter->() ) {
        $ids->{ $entry_id } = $count;
    }
    my $i = 0;
    my @entries;
    for my $entry_id (sort { $ids->{ $b } <=> $ids->{ $a } } keys %$ids) {
        my $entry = MT->model( 'entry' )->load( $entry_id );
        if ( $entry && $entry->status == MT::Entry::RELEASE() ) {
            push ( @entries, $entry );
            $i++;
            if ( $i >= $lastn ) {
                last;
            }
        }
    }
    my $res = '';
    my $i = 0;
    my $odd = 1; my $even = 0;
    my $tokens = $ctx->stash( 'tokens' );
    my $builder = $ctx->stash( 'builder' );
    for my $entry ( @entries ) {
        local $ctx->{ __stash }->{ vars }->{ __first__ } = 1 if ( $i == 0 );
        local $ctx->{ __stash }{ entry } = $entry;
        local $ctx->{ __stash }{ blog } = $entry->blog;
        local $ctx->{ __stash }{ blog_id } = $entry->blog_id;
        local $ctx->{ __stash }->{ vars }->{ __counter__ } = $i + 1;
        local $ctx->{ __stash }->{ vars }->{ __odd__ } = $odd;
        local $ctx->{ __stash }->{ vars }->{ __even__ } = $even;
        local $ctx->{ __stash }->{ vars }->{ __last__ } = 1 if ( !defined( $entries[ $i + 1 ] ) );
        my $out = $builder->build( $ctx, $tokens, $cond );
        if ( !defined( $out ) ) { return $ctx->error( $builder->errstr ) };
        $res .= $out;
        if ( $odd == 1 ) { $odd = 0 } else { $odd = 1 };
        if ( $even == 1 ) { $even = 0 } else { $even = 1 };
        $i++;
    }
    $res;
}

1;