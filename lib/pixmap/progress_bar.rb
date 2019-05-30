class ProgressBar
  def initialize(max)
    $stdout.sync = true
    @progress_max = max
    @progress_pos = 0
    @progress_view = 68
    $stdout.print "[#{'-'*@progress_view}]\r["
  end

  def update(n)
    new_pos = n * @progress_view/@progress_max
    if new_pos > @progress_pos
      @progress_pos = new_pos
      $stdout.print '='
    end
  end

  def close
    $stdout.puts '=]'
  end
end
