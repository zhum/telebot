class TelebotAsync
  TMOUT=0.2
  def initialize(queue)
    @queue = queue
  end
  def run!
    @thread=Thread.new {
      loop{
        if @queue.empty?
          sleep TMOUT
        else
          x=@queue.shift
          yield x
        end
      }
    }
  end

  def kill
    @thread.exit
  end
end

