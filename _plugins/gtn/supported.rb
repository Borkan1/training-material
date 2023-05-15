module Gtn
  module Supported
    ##
    # Identify the servers that support a given tool list
    #
    # Params:
    # +data+:: The data from metadata/public-server-tools.json
    # +tool_list+:: The list of tools to check (either 'upload1' or 'toolshed.g2.bx.psu.edu/repos/iuc/circos/circos/0.69.8+galaxy10' style tools)
    # Returns:
    # +supported+:: A hash of supported servers, with the following structure:
    #  {
    #    exact: [server1, server2, ...],
    #    inexact: [server1, server2, ...]
    #  }
    def self.calculate(data, tool_list)
      # p "Calculating supported servers for this tool list"

      supported = { exact: {}, inexact: {} }
      tool_list.each do |tool|
        if tool.count('/') > 4
          # E.g. toolshed.g2.bx.psu.edu/repos/iuc/circos/circos/0.69.8+galaxy10
          tool_id = tool.split('/')[0..4].join('/')
          tool_version = tool.split('/')[5..].join('/')
          # p "Checking #{tool_id} #{tool_version}... "

          if data['tools'].key?(tool_id)
            supported[:exact][tool] = data['tools'][tool_id][tool_version] if data['tools'][tool_id].key?(tool_version)

            supported[:inexact][tool] = data['tools'][tool_id].map { |_, v| v }.flatten.uniq.sort
          end
        elsif data['tools'].key?(tool)
          # E.g. 'upload1'
          # p "Checking #{tool}... "
          supported[:inexact][tool] = data['tools'][tool].map { |_, v| v }.flatten.uniq.sort
          supported[:exact][tool] = data['tools'][tool].map { |_, v| v }.flatten.uniq.sort
        end
      end

      # Exactly supporting servers:
      # this is the set of intersections across supported[:exact][*]
      exact_support = (0..data['servers'].length - 1).to_a
      for tool in tool_list
        exact_support &= (supported[:exact][tool] || [])
      end

      # Inexactly supporting servers
      # Set of intersections across (union of supported[:exact] and supported[:inexact])
      inexact_support = (0..data['servers'].length - 1).to_a
      for tool in tool_list
        et = supported[:exact][tool] || []
        it = supported[:inexact][tool] || []
        inexact_support &= (et | it)
      end
      # Remove the exactly supported ones because that would be extraneous
      # we check here if it's an array because the above code will occasionally generate a 'false' value when merging sets.
      inexact_support -= exact_support

      {
        "exact" => (exact_support || []).map { |id| data['servers'][id].update(
          {"usegalaxy" => data['servers'][id]['url'].downcase.include?("usegalaxy.").to_s})
        },
        "inexact" => (inexact_support || []).map { |id| data['servers'][id] }
      }
    end
  end
end

## Allow running from the CLI
if __FILE__ == $0
  if ARGV.length > 0 and ARGV[0] == 'test'
    require 'test/unit'
    class IntersectionTest < Test::Unit::TestCase
      def test_exact
        data = {
          'servers' => { 0 => 's0', 1 => 's1', 2 => 's2' },
          'tools' => {
            'upload1' => {
              '_' => [0, 1, 2]
            },
            'ts/repos/hexy/lena/tool1' => {
              '1.0' => [0, 1],
              '2.0' => [0, 2]
            }
          }
        }

        # Inexact here is empty because all are exactly supporting
        assert_equal(Gtn::Supported.calculate(data, ['upload1']), { exact: %w[s0 s1 s2], inexact: [] })
        assert_equal(Gtn::Supported.calculate(data, ['upload1', 'ts/repos/hexy/lena/tool1/1.0']),
                     { exact: %w[s0 s1], inexact: %w[s2] })
        assert_equal(Gtn::Supported.calculate(data, ['upload1', 'ts/repos/hexy/lena/tool1/2.0']),
                     { exact: %w[s0 s2], inexact: %w[s1] })
        assert_equal(Gtn::Supported.calculate(data, ['upload1', 'unknown-tool']),
                     { exact: %w[], inexact: %w[] })
      end
    end
  else
    require 'pp'
    require 'json'
    pp ARGV
    pp Gtn::Supported.calculate(JSON.load(File.open('metadata/public-server-tools.json')) , ARGV)
  end
end
