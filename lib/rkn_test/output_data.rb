module RknTest
  module OutputData
    MESSAGES = {
      unknown_schemes: "\n ------------------\n| Unknown schemes: |\n ------------------\n",
      not_blocked_pages: "\n --------------------\n| Not blocked pages: |\n --------------------\n"
    }.freeze
    def display(values)
      values.each do |key, value|
        break unless MESSAGES.key?(key)
        next if value.empty?
        msg = MESSAGES[key]
        puts msg
        puts value
      end
    end
    private :display
  end
end
