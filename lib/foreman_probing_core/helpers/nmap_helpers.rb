require 'nokogiri'
require 'open3'

module ForemanProbingCore
  module Helpers
    module NmapHelper

      if ForemanProbingCore.can_use_nmap?

        def nmap_probe
          command = ['nmap', nmap_ipv6_flag, nmap_arguments, nmap_flags, @host.to_s, with_ports(@ports)].flatten
          result = {}
          status = nil
          Open3.popen3(*command) do |_stdin, stdout, stderr, wait_thr|
            wait_thr.join
            result[:out] = stdout.read
            result[:err] = stderr.read
            status = wait_thr.value
          end
          @result = if status.success?
            process_result(xml_to_hash(result[:out]).first)
          else
            parse_error(result[:err])
          end
        end

        private

        def nmap_flags 
          raise NotImplementedError
        end

        def nmap_arguments
          %w(-oX -)
        end

        def nmap_ipv6_flag
          @host.ipv6? ? '-6' : ''
        end

        def process_result(hash)
          hash
        end

        def xml_to_hash(output)
          dom = Nokogiri.parse(output)
          dom.xpath('/nmaprun/host').map do |host|
            host.xpath('status').each do |attrs|
              attrs = reduce_attributes(attrs)
              state = attrs.delete('state')
              reason = attrs.delete('reason')
              result_builder.state(state, reason, attrs)
            end
            address = host.xpath('address').each do |hash|
              attrs = reduce_attributes(hash)
              addr = attrs.delete('addr')
              type = attrs.delete('addrtype')
              result_builder.address(addr, type, attrs)
            end
            hostnames = host.xpath('hostnames').each do |hostname|
              if hostname.attributes.key?('hostname')
                result_builder.hostname(hostname.attributes['hostname'].value)
              end
            end
            ports = host.xpath('ports/port').map do |port|
              attrs = reduce_attributes(port)
              protocol = attrs.delete('protocol')
              portid = attrs.delete('portid')

              inner = port.children.reduce({}) do |acc, cur|
                acc.merge(cur.name => reduce_attributes(cur))
              end

              service_name = inner['service'].delete('name')
              state = inner['state'].delete('state')
              result_builder.port(protocol, portid, state,
                                  service_name, inner['state'], inner['service'])
            end
            result_builder.result
          end
        end

        def reduce_attributes(dom)
          Hash[dom.keys.zip(dom.values)]
        end

        def with_ports(ports)
          return '' if ports.empty?
          "-p #{ports.join(',')}"
        end

      end

    end
  end
end