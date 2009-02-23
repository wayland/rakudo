class Range is also {

    multi method perl() {
        my $out = $.from.perl;
        $out ~= '^' if $!from_exclusive;
        $out ~= '..';
        $out ~= '^' if $!to_exclusive;
        $out ~= $.to.perl;
        return $out;
    }

    multi method ACCEPTS($topic) {
         my Bool $from_truth = $!from_exclusive 
                                  ?? ($!from cmp $topic) > 0
                                  !! ($!from cmp $topic) >= 0;
         my Bool $to_truth   = $!to_exclusive   
                                  ?? ($!to   cmp $topic)  < 0
                                  !! ($!to   cmp $topic) <= 0;
         return $from_truth && $to_truth;
    }
}

# vim: ft=perl6
