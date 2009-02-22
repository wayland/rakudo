class Range is also {

    method perl() {
	my $out = self.from.perl;
	$out ~= '^' if($!from_exclusive);
	$out ~= '..';
	$out ~= '^' if($!to_exclusive);
	$out ~= self.to.perl;
	return $out;
    }

    method ACCEPTS($topic) {
         my Bool $from_truth = Bool::True;
         my Bool $to_truth = Bool::True;
         $from_truth = $topic > $!from;
	 $from_truth &= $topic == $!from if !$!from_exclusive;
         $to_truth = $topic < $!to;
	 $to_truth &= $topic == $!to if !$!to_exclusive;
	 return $from_truth && $to_truth;
    }
}
