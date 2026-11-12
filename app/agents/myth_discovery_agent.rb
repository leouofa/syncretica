# frozen_string_literal: true

class MythDiscoveryAgent < ApplicationAgent
  inputs :god_name, :god_description, :god_themes, :pantheon_name

  ZEUS_EXAMPLE_JSON = <<~JSON.strip
    {
      "Breaking the Generational Curse": "Ending the cyclical patricide of Ouranos and Cronus by overthrowing his father, freeing his siblings, and outmaneuvering prophecy through preemptive intelligence.",
      "Cosmic Order vs. Primordial Chaos": "Establishing celestial rule over chthonic, monstrous forces through decisive warfare in the Titanomachy, Typhonomachy, and Gigantomachy.",
      "Sovereignty and the Partition of Power": "Instituting legitimate divine governance by casting lots with Poseidon and Hades to divide the cosmos while retaining supreme oversight.",
      "Justice and Civic Moral Law (Themis and Dike)": "Serving as the divine guarantor of societal codes, upholding hospitality (Zeus Xenios), solemn oaths (Zeus Horkios), and suppliant protection (Zeus Hikesios).",
      "Dynastic Proliferation and Theological Synthesis": "Consolidating cosmic and regional authority by fathering Olympians to govern essential domains and hero lineages to legitimize Greek city-states.",
      "Submission to Fate (Moira)": "Navigating the constraints of universal cosmic law, recognizing that even supreme divine authority cannot override predestined decrees such as the death of Sarpedon.",
      "Punishment of Mortal Overreach (Hubris)": "Enforcing the boundary between humanity and divinity by crushing arrogance and impiety in figures like Prometheus, Lycaon, and Salmoneus.",
      "Metamorphosis as Divine Penetration": "Employing shapeshifting—such as an eagle, bull, or shower of gold—to traverse physical and ontological boundaries between heaven and the mortal sphere.",
      "Divine Hierarchy and Internal Olympian Conflict": "Maintaining domestic and political dominion amidst palace rebellions, spousal friction with Hera, and disputes among rival gods.",
      "Arbitration of Human Destiny": "Weighing the fates of armies on golden scales (kerostasia) and dispensing good and evil from twin cosmic jars to govern historical outcomes."
    }
  JSON

  instructions do
    themes_list = Array(god_themes).compact_blank
    themes_clause = themes_list.any? ? "Associated domains/motifs: #{themes_list.join(', ')}." : ""
    description_clause = god_description.present? ? "Deity context: #{god_description}" : ""

    <<~INSTRUCTIONS.strip
      You are a comparative mythology scholar analyzing #{god_name} from the #{pantheon_name} pantheon.
      #{description_clause}
      #{themes_clause}

      Synthesize 8 to 10 core mythical themes that define #{god_name}'s narratives, theology, and symbolic role.
      For each mythical theme, provide:
      1. A concise, evocative theme title as the JSON key.
      2. A single, scholarly sentence describing how that theme manifests in #{god_name}'s myths and attributes as the JSON value.

      For example, for Zeus in the Greek pantheon, the output should look like:
      #{ZEUS_EXAMPLE_JSON}

      Respond ONLY with a single valid JSON object mapping each theme title to its description (no markdown fences, arrays, or commentary).
    INSTRUCTIONS
  end
end
