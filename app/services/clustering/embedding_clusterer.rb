# frozen_string_literal: true

module Clustering
  class EmbeddingClusterer
    THRESHOLD_MAP = {
      1 => 0.16,
      2 => 0.17,
      3 => 0.18,
      4 => 0.19,
      5 => 0.20,
      6 => 0.21,
      7 => 0.22,
      8 => 0.23,
      9 => 0.24,
      10 => 0.25,
      11 => 0.24,
      12 => 0.24,
      13 => 0.24,
      14 => 0.23,
      15 => 0.22
    }.freeze

    ABSORPTION_FRACTIONS = {
      11 => 0.25,
      12 => 0.50,
      13 => 0.75,
      14 => 0.90,
      15 => 1.00
    }.freeze

    Cluster = Struct.new(:id, :name, :shared_themes, :records, :size, :pantheons, keyword_init: true)

    class Result
      attr_reader :target_class, :level, :distance_threshold, :total_embedded_count,
                  :clusters, :singletons, :full_coverage, :generated_at

      def initialize(target_class:, level:, distance_threshold:, total_embedded_count:, clusters:, singletons:, full_coverage: false)
        @target_class = target_class
        @level = level
        @distance_threshold = distance_threshold
        @total_embedded_count = total_embedded_count
        @clusters = clusters
        @singletons = singletons
        @full_coverage = full_coverage
        @generated_at = Time.current
      end

      def target_name
        @target_class.model_name.human.pluralize
      end

      def multi_clusters_count
        @clusters.size
      end

      def singletons_count
        @singletons.size
      end

      def largest_cluster_size
        @clusters.map(&:size).max || 0
      end

      def full_coverage?
        @full_coverage || singletons_count.zero?
      end

      def snapshot!(title:)
        clean_title = title.to_s.squish.presence || "#{target_class.name} Clusters - Level #{level}#{' (Full Coverage)' if full_coverage?} (#{Time.current.strftime('%b %d, %Y')})"

        ClusterSnapshot.transaction do
          snapshot = ClusterSnapshot.create!(
            target_type: @target_class.name,
            level: @level,
            distance_threshold: @distance_threshold,
            title: clean_title,
            clusters_count: @clusters.size,
            items_count: @total_embedded_count
          )

          @clusters.each do |cluster|
            group = snapshot.cluster_groups.create!(
              name: cluster.name,
              shared_themes: cluster.shared_themes,
              size: cluster.size
            )

            memberships = cluster.records.map do |record|
              {
                cluster_group_id: group.id,
                record_type: @target_class.name,
                record_id: record.id,
                created_at: Time.current,
                updated_at: Time.current
              }
            end

            ClusterMembership.insert_all!(memberships) if memberships.any?
          end

          snapshot
        end
      end
    end

    def self.call(target_class, level: 5, full_coverage: false, force: false)
      new(target_class, level: level, full_coverage: full_coverage, force: force).call
    end

    def initialize(target_class, level: 5, full_coverage: false, force: false)
      @target_class = target_class
      @level = level.to_i.clamp(1, 15)
      @threshold = THRESHOLD_MAP.fetch(@level, 0.22)
      @full_coverage = full_coverage || @level >= 15
      @force = force
    end

    def call
      if @force
        compute
      else
        Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          compute
        end
      end
    end

    private

    def cache_key
      max_updated = @target_class.maximum(:updated_at)&.to_i || 0
      embedded_count = @target_class.where.not(embedding: nil).count
      "clusters/v3/#{@target_class.name.downcase}/level-#{@level}/t-#{@threshold}/fc-#{@full_coverage ? 1 : 0}/#{max_updated}/#{embedded_count}"
    end

    def compute
      records_scope = @target_class.where.not(embedding: nil)
      embedded_ids = records_scope.pluck(:id)

      if embedded_ids.empty?
        return Result.new(
          target_class: @target_class,
          level: @level,
          distance_threshold: @threshold,
          total_embedded_count: 0,
          clusters: [],
          singletons: [],
          full_coverage: @full_coverage
        )
      end

      pairs = fetch_pairs
      parent = {}

      find = ->(i) {
        parent[i] ||= i
        path = []
        while parent[i] != i
          path << i
          i = parent[i]
        end
        path.each { |node| parent[node] = i }
        i
      }

      pairs.each do |a, b|
        root_a = find.call(a)
        root_b = find.call(b)
        parent[root_a] = root_b if root_a != root_b
      end

      components = Hash.new { |h, k| h[k] = [] }
      embedded_ids.each do |id|
        components[find.call(id)] << id
      end

      multi_components = []
      singleton_ids = []

      components.each_value do |member_ids|
        if member_ids.size > 1
          multi_components << member_ids
        else
          singleton_ids.concat(member_ids)
        end
      end

      # Determine absorption fraction based on level and full_coverage flag
      fraction = if @full_coverage
                   1.0
      else
                   ABSORPTION_FRACTIONS.fetch(@level, 0.0)
      end

      if fraction > 0.0 && multi_components.any? && singleton_ids.any?
        absorb_singletons!(multi_components, singleton_ids, max_fraction: fraction)
      end

      # Order clusters by size descending
      multi_components.sort_by! { |ids| -ids.size }

      # Eager load records with associations
      record_loader = @target_class.includes(eager_load_associations)
      all_records_by_id = record_loader.where(id: embedded_ids).index_by(&:id)

      clusters = multi_components.each_with_index.map do |member_ids, index|
        records = member_ids.filter_map { |id| all_records_by_id[id] }
        label_data = HeuristicLabeler.label(records)
        pantheons = extract_pantheons(records)

        Cluster.new(
          id: index + 1,
          name: label_data[:title],
          shared_themes: label_data[:shared_themes],
          records: records,
          size: records.size,
          pantheons: pantheons
        )
      end

      singletons = singleton_ids.filter_map { |id| all_records_by_id[id] }
      singletons.sort_by! { |rec| entity_name(rec).downcase }

      Result.new(
        target_class: @target_class,
        level: @level,
        distance_threshold: @threshold,
        total_embedded_count: embedded_ids.size,
        clusters: clusters,
        singletons: singletons,
        full_coverage: @full_coverage
      )
    end

    def absorb_singletons!(multi_components, singleton_ids, max_fraction: 1.0)
      return if multi_components.empty? || singleton_ids.empty?

      table = @target_class.table_name
      clustered_ids = multi_components.flatten

      sql = <<-SQL.squish
        WITH clustered AS (
          SELECT id, embedding FROM #{table} WHERE id IN (#{clustered_ids.join(',')})
        )
        SELECT s.id, (
          SELECT c.id FROM clustered c ORDER BY s.embedding <=> c.embedding LIMIT 1
        ), (
          SELECT (s.embedding <=> c.embedding) FROM clustered c ORDER BY s.embedding <=> c.embedding LIMIT 1
        ) AS dist
        FROM #{table} s
        WHERE s.id IN (#{singleton_ids.join(',')})
        ORDER BY dist ASC
      SQL

      rows = ActiveRecord::Base.connection.select_rows(sql)
      to_absorb = (rows.size * max_fraction).ceil
      absorbed_rows = rows.take(to_absorb)

      god_to_component_idx = {}
      multi_components.each_with_index do |member_ids, idx|
        member_ids.each { |gid| god_to_component_idx[gid] = idx }
      end

      absorbed_ids = Set.new
      absorbed_rows.each do |s_id, nearest_c_id, _|
        idx = god_to_component_idx[nearest_c_id]
        if idx
          multi_components[idx] << s_id
          absorbed_ids << s_id
        end
      end

      singleton_ids.reject! { |id| absorbed_ids.include?(id) }
    end

    def fetch_pairs
      table = @target_class.table_name
      sql = <<-SQL.squish
        SELECT a.id, b.id
        FROM #{table} a
        JOIN #{table} b ON a.id < b.id
        WHERE a.embedding IS NOT NULL
          AND b.embedding IS NOT NULL
          AND (a.embedding <=> b.embedding) <= :threshold
      SQL

      sanitized = ActiveRecord::Base.sanitize_sql_array([ sql, { threshold: @threshold } ])
      ActiveRecord::Base.connection.select_rows(sanitized)
    end

    def eager_load_associations
      case @target_class.name
      when "God" then :pantheon
      when "Myth" then { god: :pantheon }
      else []
      end
    end

    def extract_pantheons(records)
      records.map do |record|
        case record
        when God then record.pantheon&.name
        when Myth then record.god&.pantheon&.name
        end
      end.compact.uniq.sort
    end

    def entity_name(record)
      case record
      when God then record.name
      when Myth then "#{record.god&.name} Myth"
      else record.to_s
      end
    end
  end
end
