# frozen_string_literal: true

module Zendesk
  class Snitcher
    class Thread < Zendesk::Snitcher
      def update(options)
        tickets = super
        return unless tickets

        tickets.each do |ticket|
          Thread.new do
            zd_thread_ts = zd_value_by(:thread_ts, ticket["custom_fields"])
            unless same_reaction_as?(reaction_by(ticket["status"]), zd_thread_ts)
              unless ticket["status"] == "solved" && same_reaction_as?(reaction_by("pending"), zd_thread_ts)
                notify_thread_about_status(ticket["status"], ticket["id"], zd_thread_ts)
              end
              update_reaction(reaction_by(ticket["status"]), zd_thread_ts)
            end
          end
        end
      end

      private

      def find_reaction_data(reactions_hash, emoji_name)
        return [] unless reactions_hash

        reactions_hash.select do |reaction_data|
          reaction_data["name"] == emoji_name.to_s
        end
      end

      def reaction_by(status)
        Zendesk::Request::Ticket::STATUSES[status]
      end

      def remove_all_reactions(thread_ts)
        Zendesk::Request::Ticket::STATUSES.each do |_status_name, emoji_name|
          slack.reactions_remove(name: emoji_name, channel_id: channel_id, thread_ts: thread_ts).push
        end
      end

      def update_reaction(emoji_name, thread_ts)
        remove_all_reactions(thread_ts)
        slack.reactions_add(name: emoji_name, channel_id: channel_id, thread_ts: thread_ts).push
      end

      def same_reaction_as?(emoji_name, zd_thread_ts)
        reaction_data = find_reaction_data(slack_thread(zd_thread_ts, 1)["messages"].first["reactions"], emoji_name)
        return if reaction_data.empty?

        reaction_data.first["name"]
      end

      def notify_thread_about_status(status, ticket_id, zd_thread_ts)
        text = Zendesk::Text.ticket_on_status(status, ticket_id)
        return unless text

        send_message(text, zd_thread_ts)
      end
    end
  end
end
