# frozen_string_literal: true

module Clustering
  # Serializes all clusters and items in a ClusterSnapshot into a rich, structured,
  # token-budget-aware text digest for comparative LLM reporting.
  class SnapshotDigestBuilder
    DEFAULT_MAX_CHARS = 120_000

    def self.call(snapshot, max_chars: DEFAULT_MAX_CHARS)
      new(snapshot, max_chars: max_chars).call
    end

    def initialize(snapshot, max_chars: DEFAULT_MAX_CHARS)
      @snapshot = snapshot
      @max_chars = max_chars
    end

    def call
      groups = @snapshot.cluster_groups.by_size.includes(cluster_memberships: eager_associations)
      target_type = @snapshot.target_type

      # Compute overall pantheon coverage
      pantheon_counts = Hash.new(0)
      groups.each do |group|
        group.cluster_memberships.each do |m|
          record = m.record
          next unless record

          p_name = record_pantheon_name(record)
          pantheon_counts[p_name] += 1 if p_name.present?
        end
      end

      top_pantheons = pantheon_counts.sort_by { |_, c| -c }.first(10)
        .map { |name, count| "#{name} (#{count})" }.join(", ")

      header = <<~HEADER
        === CLUSTER SNAPSHOT OVERVIEW ===
        Title: #{@snapshot.title}
        Target Type: #{target_type}
        Clustering Level: #{@snapshot.level} (distance threshold <= #{@snapshot.distance_threshold})
        Total Clusters: #{@snapshot.clusters_count}
        Total Persisted Items: #{@snapshot.items_count}
        Represented Pantheons: #{top_pantheons}
        Generated At: #{@snapshot.created_at.strftime('%Y-%m-%d %H:%M UTC')}
        =================================

        CLUSTERS (#{groups.size} total):
      HEADER

      char_budget_remaining = @max_chars - header.length
      cluster_blocks = []

      # Allocate per-cluster member details budget
      budget_per_group = [ (char_budget_remaining / [ groups.size, 1 ].max).to_i, 400 ].max

      groups.each_with_index do |group, idx|
        cluster_blocks << format_cluster(group, rank: idx + 1, target_type: target_type, member_budget: budget_per_group)
      end

      full_digest = ([ header.strip ] + cluster_blocks).join("\n\n")
      if full_digest.length > @max_chars
        full_digest.truncate(@max_chars, omission: "\n\n... [Digest truncated to fit context budget] ...")
      else
        full_digest
      end
    end

    private

    def eager_associations
      case @snapshot.target_type
      when "God"
        { record: :pantheon }
      when "Myth"
        { record: { god: :pantheon } }
      else
        :record
      end
    end

    def record_pantheon_name(record)
      case record
      when God then record.pantheon&.name
      when Myth then record.god&.pantheon&.name
      end
    end

    def format_cluster(group, rank:, target_type:, member_budget:)
      # Pantheon distribution in this cluster
      group_pantheons = Hash.new(0)
      memberships = group.cluster_memberships.to_a

      memberships.each do |m|
        next unless m.record

        p_name = record_pantheon_name(m.record)
        group_pantheons[p_name] += 1 if p_name.present?
      end

      pantheon_dist = group_pantheons.sort_by { |_, c| -c }
        .map { |name, count| "#{name}: #{count}" }.join(", ")

      themes_str = group.shared_themes.presence ? group.shared_themes.join(", ") : "None specified"

      lines = [
        "### Cluster ##{rank}: \"#{group.name}\"",
        "Size: #{group.size} #{target_type.pluralize.downcase}",
        "Dominant Pantheons: #{pantheon_dist.presence || 'None'}",
        "Shared Themes: #{themes_str}",
        "Members:"
      ]

      # Render condensed members up to the allotted budget
      members_text = format_members(memberships, target_type: target_type, budget: member_budget)
      lines << members_text

      lines.join("\n")
    end

    def format_members(memberships, target_type:, budget:)
      return "  (none)" if memberships.empty?

      member_lines = []
      used_chars = 0

      memberships.each_with_index do |m, idx|
        record = m.record
        next unless record

        line = case target_type
        when "God"
          format_god_member(record)
        when "Myth"
          format_myth_member(record)
        else
          "  - #{record.id}"
        end

        if used_chars + line.length > budget && idx < memberships.size - 1
          remaining = memberships.size - idx
          member_lines << "  - ... and #{remaining} more #{target_type.pluralize.downcase}"
          break
        end

        member_lines << line
        used_chars += line.length
      end

      member_lines.join("\n")
    end

    def format_god_member(god)
      pantheon_name = god.pantheon&.name || "Unknown"
      themes_str = god.themes.presence ? " [themes: #{god.themes.first(4).join(', ')}]" : ""
      desc_snippet = god.description.to_s.squish.truncate(90)
      "  - #{god.name} (#{pantheon_name})#{themes_str}: #{desc_snippet}"
    end

    def format_myth_member(myth)
      god_name = myth.god&.name || "Unknown God"
      pantheon_name = myth.god&.pantheon&.name || "Unknown"
      top_themes = myth.themes.is_a?(Hash) ? myth.themes.keys.first(3).join("; ") : ""
      themes_snippet = top_themes.present? ? " [motifs: #{top_themes}]" : ""
      first_theme_desc = myth.themes.is_a?(Hash) && myth.themes.values.first.present? ? myth.themes.values.first.to_s.squish.truncate(80) : ""
      desc_part = first_theme_desc.present? ? ": #{first_theme_desc}" : ""

      "  - #{god_name} Myth (#{pantheon_name})#{themes_snippet}#{desc_part}"
    end
  end
end
