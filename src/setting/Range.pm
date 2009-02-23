class Range is also {

    method perl() {
        my $out = $.from.perl;
        $out ~= '^' if $!from_exclusive;
        $out ~= '..';
        $out ~= '^' if $!to_exclusive;
        $out ~= $.to.perl;
        return $out;
    }

    method ACCEPTS($topic) {
         my Bool $from_truth = $!from_exclusive 
                                  ??  $!from < $topic
                                  !! $!from <= $topic;
         my Bool $to_truth   = $!to_exclusive   
                                  ??  $!to  <  $topic
                                  !! $!from <= $topic;
         return $from_truth && $to_truth;
    }
}
