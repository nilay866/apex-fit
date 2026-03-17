#!/usr/bin/env python3

import json
import re
import urllib.request
from collections import defaultdict
from pathlib import Path

SOURCE_URL = (
    "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json"
)
OUTPUT_PATH = Path("assets/data/exercise_catalog.json")


def title_case(value: str | None, fallback: str) -> str:
    if not value:
        return fallback
    normalized = value.replace("-", " ").strip()
    return " ".join(part.capitalize() for part in normalized.split())


def map_difficulty(level: str | None) -> str:
    return {
        "beginner": "Beginner",
        "intermediate": "Intermediate",
        "expert": "Advanced",
    }.get((level or "").lower(), "Intermediate")


def map_equipment(equipment: str | None) -> str:
    return {
        "body only": "Bodyweight",
        "e-z curl bar": "EZ Curl Bar",
        "kettlebells": "Kettlebell",
        "bands": "Resistance Band",
        "medicine ball": "Medicine Ball",
        "exercise ball": "Exercise Ball",
        "foam roll": "Foam Roller",
        "other": "Other",
        "": "Other",
    }.get((equipment or "").lower(), title_case(equipment, "Other"))


def map_environment(equipment: str | None) -> str:
    normalized = (equipment or "").lower()
    if normalized in {"barbell", "cable", "machine", "e-z curl bar"}:
        return "Gym"
    if normalized in {
        "body only",
        "bands",
        "medicine ball",
        "exercise ball",
        "foam roll",
    }:
        return "Home"
    return "Both"


def map_primary_group(item: dict) -> str:
    category = (item.get("category") or "").lower()
    muscles = [muscle.lower() for muscle in item.get("primaryMuscles") or []]
    name = (item.get("name") or "").lower()

    if category == "cardio" or any(
        token in name for token in ["run", "jump", "burpee", "sprint", "bike", "rope"]
    ):
        return "Cardio"
    if "chest" in muscles:
        return "Chest"
    if any(muscle in muscles for muscle in ["lats", "middle back", "lower back", "traps"]):
        return "Back"
    if any(muscle in muscles for muscle in ["quadriceps", "hamstrings", "calves", "adductors"]):
        return "Legs"
    if any(muscle in muscles for muscle in ["biceps", "triceps", "forearms"]):
        return "Arms"
    if any(muscle in muscles for muscle in ["shoulders", "neck"]):
        return "Shoulders"
    if any(muscle in muscles for muscle in ["glutes", "abductors"]):
        return "Glutes"
    if "abdominals" in muscles:
        return "Core"
    return "Core"


def map_animation_key(item: dict) -> str:
    name = (item.get("name") or "").lower()
    category = (item.get("category") or "").lower()
    mechanic = (item.get("mechanic") or "").lower()
    primary = " ".join(item.get("primaryMuscles") or []).lower()

    if category in {"cardio", "plyometrics"}:
        return "cardio"

    rules = [
        ("push", ["push-up", "push up", "bench press", "chest press", "dip"]),
        ("press", ["press", "jerk", "fly", "crossover", "pec deck", "handstand"]),
        ("row", ["row", "pullover"]),
        ("pull", ["pull-up", "pull up", "chin-up", "chin up", "pulldown", "pull-down"]),
        ("raise", ["raise", "shrug", "upright row", "reverse fly", "neck"]),
        ("curl", ["curl"]),
        (
            "pushdown",
            ["pushdown", "push-down", "extension", "kickback", "skull crusher", "triceps overhead"],
        ),
        (
            "squat",
            ["squat", "leg press", "leg extension", "hack squat", "thruster", "clean", "front squat", "zercher"],
        ),
        ("lunge", ["lunge", "split squat", "step-up", "step up", "walking"]),
        (
            "bridge",
            [
                "deadlift",
                "romanian",
                "rdl",
                "good morning",
                "hip thrust",
                "bridge",
                "swing",
                "pull-through",
                "hyperextension",
                "glute ham",
            ],
        ),
        (
            "core",
            [
                "balance board",
                "sit-up",
                "sit up",
                "crunch",
                "plank",
                "twist",
                "wood chop",
                "woodchop",
                "russian",
                "jackknife",
                "v-up",
                "rollout",
                "roll-out",
                "mountain climber",
                "dead bug",
                "bird dog",
                "hanging leg raise",
                "leg raise",
            ],
        ),
        (
            "cardio",
            ["run", "jump", "burpee", "jack", "high knees", "battle rope", "rope", "sprint", "march", "skip", "sled"],
        ),
    ]

    for key, patterns in rules:
        if any(pattern in name for pattern in patterns):
            return key

    if "neck" in primary:
        return "raise"
    if "abdominals" in primary or "waist" in primary:
        return "core"
    if any(muscle in primary for muscle in ["glutes", "hamstrings", "lower back"]):
        return "bridge"
    if any(muscle in primary for muscle in ["quadriceps", "adductors", "abductors"]):
        return "squat"
    if any(muscle in primary for muscle in ["lats", "middle back", "traps"]):
        return "row"
    if "chest" in primary:
        return "press"
    if "shoulders" in primary:
        return "raise" if "isolation" in mechanic else "press"
    if any(muscle in primary for muscle in ["biceps", "forearms"]):
        return "curl"
    if "triceps" in primary:
        return "pushdown"

    return "core"


def build_muscle_heatmap(item: dict) -> list[dict]:
    grouped: defaultdict[str, int] = defaultdict(int)

    for muscle in item.get("primaryMuscles") or []:
        grouped[map_primary_group({"primaryMuscles": [muscle]})] = max(
            grouped[map_primary_group({"primaryMuscles": [muscle]})],
            5,
        )

    for muscle in item.get("secondaryMuscles") or []:
        grouped[map_primary_group({"primaryMuscles": [muscle]})] = max(
            grouped[map_primary_group({"primaryMuscles": [muscle]})],
            3,
        )

    if not grouped:
        grouped[map_primary_group(item)] = 5

    return [
        {"muscle": muscle, "intensity": intensity}
        for muscle, intensity in sorted(grouped.items())
    ]


def normalize_name(name: str) -> str:
    return re.sub(r"\s+", " ", name).strip()


def build_beginner_tip(item: dict, environment: str) -> str:
    level = map_difficulty(item.get("level"))
    equipment = map_equipment(item.get("equipment"))
    if level == "Beginner":
        return (
            "Start light, own the full range of motion, "
            "and keep every rep smooth before adding load or speed."
        )
    if environment == "Home":
        return (
            "This movement works well at home. "
            "Use controlled reps and stop before your form changes."
        )
    if equipment in {"Barbell", "Machine", "Cable"}:
        return (
            "Use a conservative setup first and lock in the path "
            "before pushing the weight."
        )
    return ""


def transform(item: dict) -> dict | None:
    category = (item.get("category") or "").lower()
    name = normalize_name(item.get("name") or "")
    if not name or category == "stretching":
        return None

    environment = map_environment(item.get("equipment"))
    primary_group = map_primary_group(item)
    instructions = [
        step.strip() for step in item.get("instructions") or [] if step.strip()
    ]

    return {
        "id": f"free_exercise_db_{item.get('id')}",
        "name": name,
        "primary_muscle": primary_group,
        "equipment": map_equipment(item.get("equipment")),
        "environment": environment,
        "difficulty": map_difficulty(item.get("level")),
        "animation_key": map_animation_key(item),
        "video_url": "",
        "taxonomy_folder": title_case(item.get("category"), "Strength"),
        "instructions": instructions,
        "beginner_tip": build_beginner_tip(item, environment),
        "muscle_heatmap": build_muscle_heatmap(item),
        "source": "free-exercise-db",
        "source_url": "https://github.com/yuhonas/free-exercise-db",
    }


def fetch_source() -> list[dict]:
    with urllib.request.urlopen(SOURCE_URL) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> None:
    raw_items = fetch_source()
    catalog = []
    seen = set()

    for item in raw_items:
        normalized = transform(item)
        if not normalized:
            continue
        key = normalized["name"].lower()
        if key in seen:
            continue
        seen.add(key)
        catalog.append(normalized)

    catalog.sort(key=lambda entry: entry["name"].lower())
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(catalog, indent=2), encoding="utf-8")
    print(f"Wrote {len(catalog)} exercises to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
