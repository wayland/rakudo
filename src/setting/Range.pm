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
         my Bool $!from_exclusive ?? $!from <  $topic.from 
                                  !! $!from <= $topic.from;
         my Bool $!to_exclusive   ??  $!to  <  $topic.to
                                  !! $!from <= $topic.to;
         return $from_truth && $to_truth;
    }
}
