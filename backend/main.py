from datetime import datetime
from typing import List, Optional, Dict, Any

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(title="Smart Study Planner AI Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# -----------------------------
# Models
# -----------------------------
class ProfileIn(BaseModel):
    name: Optional[str] = ""
    semester: Optional[str] = ""
    wakeTime: str = "07:00"
    sleepTime: str = "23:00"
    preferredStudyHours: int = 4
    maxStudyBlockMinutes: int = 90
    preferredBreakMinutes: int = 15


class SubjectIn(BaseModel):
    subjectName: str
    examDate: Optional[str] = None
    estimatedHours: int = 0
    difficultyLevel: str = "Medium"
    confidenceLevel: str = "Medium"


class TaskIn(BaseModel):
    title: str
    subjectName: str = "General"
    dueDate: Optional[str] = None
    priority: str = "Medium"
    completionStatus: Optional[str] = None
    status: Optional[str] = None
    estimatedMinutes: int = 60
    notes: Optional[str] = ""


class PyqTopicIn(BaseModel):
    subjectName: str
    topicName: str
    frequencyCount: int = 0
    marksWeight: int = 0


class BlockedSlotIn(BaseModel):
    title: str
    date: Optional[str] = None
    startTime: str
    endTime: str
    type: str = "other"
    isRecurring: bool = False
    dayOfWeek: Optional[int] = None


class GeneratePlanRequest(BaseModel):
    profile: ProfileIn
    subjects: List[SubjectIn] = Field(default_factory=list)
    tasks: List[TaskIn] = Field(default_factory=list)
    pyqTopics: List[PyqTopicIn] = Field(default_factory=list)
    blockedSlots: List[BlockedSlotIn] = Field(default_factory=list)
    forDate: Optional[str] = None


# -----------------------------
# Helpers
# -----------------------------
def parse_date(raw: Optional[str]) -> Optional[datetime]:
    if not raw:
        return None
    try:
        return datetime.fromisoformat(raw[:10])
    except Exception:
        return None


def parse_time_to_minutes(raw: str) -> int:
    parts = raw.split(":")
    if len(parts) != 2:
        return 0
    try:
        hour = int(parts[0])
        minute = int(parts[1])
    except Exception:
        return 0
    return hour * 60 + minute


def format_minutes(total_minutes: int) -> str:
    normalized = total_minutes % (24 * 60)
    hour24 = normalized // 60
    minute = normalized % 60
    period = "PM" if hour24 >= 12 else "AM"
    hour12 = 12 if hour24 % 12 == 0 else hour24 % 12
    return f"{hour12}:{str(minute).zfill(2)} {period}"


def normalize_status(task: TaskIn) -> str:
    status = (task.completionStatus or task.status or "pending").strip().lower()
    return "completed" if status == "completed" else "pending"


def task_priority_score(priority: str) -> int:
    value = priority.strip().lower()
    if value == "high":
        return 30
    if value == "medium":
        return 18
    if value == "low":
        return 8
    return 12


def confidence_score(confidence: str) -> int:
    value = confidence.strip().lower()
    if value == "low":
        return 30
    if value == "medium":
        return 15
    if value == "high":
        return 5
    return 10


def difficulty_score(difficulty: str) -> int:
    value = difficulty.strip().lower()
    if value == "hard":
        return 18
    if value == "medium":
        return 10
    if value == "easy":
        return 4
    return 8


def exam_urgency_score(exam_date: Optional[str], today: datetime) -> int:
    parsed = parse_date(exam_date)
    if not parsed:
        return 0

    days = (parsed.date() - today.date()).days
    if days <= 0:
        return 32
    if days <= 2:
        return 26
    if days <= 5:
        return 20
    if days <= 10:
        return 14
    return 6


def due_date_score(due_date: Optional[str], today: datetime) -> int:
    parsed = parse_date(due_date)
    if not parsed:
        return 0

    days = (parsed.date() - today.date()).days
    if days <= 0:
        return 35
    if days <= 1:
        return 28
    if days <= 3:
        return 22
    if days <= 7:
        return 15
    return 6


def build_pyq_subject_boost(pyq_topics: List[PyqTopicIn]) -> Dict[str, int]:
    boosts: Dict[str, int] = {}
    for item in pyq_topics:
        boosts[item.subjectName] = boosts.get(item.subjectName, 0) + (
            item.frequencyCount * 4 + item.marksWeight * 2
        )
    return boosts


def build_pyq_topic_names(pyq_topics: List[PyqTopicIn]) -> Dict[str, List[str]]:
    result: Dict[str, List[str]] = {}
    for item in pyq_topics:
        subject = item.subjectName.strip()
        topic = item.topicName.strip().lower()
        if not subject or not topic:
            continue
        result.setdefault(subject, [])
        if topic not in result[subject]:
            result[subject].append(topic)
    return result


def build_blocked_windows(
    blocked_slots: List[BlockedSlotIn],
    target_date: datetime,
    wake_minute: int,
    sleep_minute: int,
) -> List[Dict[str, int]]:
    target_date_str = target_date.strftime("%Y-%m-%d")
    windows: List[Dict[str, int]] = []

    for slot in blocked_slots:
        applies_today = False

        if slot.isRecurring:
            applies_today = slot.dayOfWeek == target_date.isoweekday()
        else:
            applies_today = slot.date == target_date_str

        if not applies_today:
            continue

        start_min = parse_time_to_minutes(slot.startTime)
        end_min = parse_time_to_minutes(slot.endTime)

        if end_min <= start_min:
            continue

        if end_min <= wake_minute or start_min >= sleep_minute:
            continue

        clipped_start = max(start_min, wake_minute)
        clipped_end = min(end_min, sleep_minute)

        if clipped_end > clipped_start:
            windows.append({"start": clipped_start, "end": clipped_end})

    windows.sort(key=lambda x: x["start"])

    if not windows:
        return []

    merged = [windows[0]]
    for current in windows[1:]:
        last = merged[-1]
        if current["start"] <= last["end"]:
            last["end"] = max(last["end"], current["end"])
        else:
            merged.append(current)

    return merged


def build_free_windows(
    wake_minute: int,
    sleep_minute: int,
    blocked_windows: List[Dict[str, int]],
) -> List[Dict[str, int]]:
    if not blocked_windows:
        return [{"start": wake_minute, "end": sleep_minute}]

    free: List[Dict[str, int]] = []
    cursor = wake_minute

    for blocked in blocked_windows:
        if blocked["start"] > cursor:
            free.append({"start": cursor, "end": blocked["start"]})
        cursor = max(cursor, blocked["end"])

    if cursor < sleep_minute:
        free.append({"start": cursor, "end": sleep_minute})

    return [window for window in free if window["end"] - window["start"] >= 25]


def build_candidates(
    profile: ProfileIn,
    subjects: List[SubjectIn],
    tasks: List[TaskIn],
    pyq_topics: List[PyqTopicIn],
    today: datetime,
) -> List[Dict[str, Any]]:
    pyq_subject_boost = build_pyq_subject_boost(pyq_topics)
    pyq_topic_names = build_pyq_topic_names(pyq_topics)

    subject_map = {subject.subjectName: subject for subject in subjects}
    candidates: List[Dict[str, Any]] = []

    for task in tasks:
        if normalize_status(task) == "completed":
            continue

        subject = subject_map.get(task.subjectName)
        difficulty = subject.difficultyLevel if subject else "Medium"
        confidence = subject.confidenceLevel if subject else "Medium"

        score = 40
        score += task_priority_score(task.priority)
        score += confidence_score(confidence)
        score += difficulty_score(difficulty)
        score += due_date_score(task.dueDate, today)
        score += pyq_subject_boost.get(task.subjectName, 0) // 5

        task_title_lower = task.title.lower()
        for topic in pyq_topic_names.get(task.subjectName, []):
            if topic in task_title_lower:
                score += 20
                break

        desired = max(25, min(task.estimatedMinutes or 60, profile.maxStudyBlockMinutes))

        candidates.append({
            "title": task.title,
            "subject_name": task.subjectName,
            "subtitle": f"Task • {task.priority} priority",
            "reason": "Ranked using due date, priority, confidence, difficulty, and PYQ relevance.",
            "score": score,
            "desired_minutes": desired,
            "type": "study",
            "source": "task",
        })

    subject_candidates: List[Dict[str, Any]] = []
    for subject in subjects:
        score = 20
        score += confidence_score(subject.confidenceLevel) + 10
        score += difficulty_score(subject.difficultyLevel)
        score += exam_urgency_score(subject.examDate, today)
        score += pyq_subject_boost.get(subject.subjectName, 0) // 4
        score += max(0, min(subject.estimatedHours, 10))

        if subject.difficultyLevel.lower() == "hard":
            desired = min(profile.maxStudyBlockMinutes, 90)
        elif subject.difficultyLevel.lower() == "medium":
            desired = min(profile.maxStudyBlockMinutes, 60)
        else:
            desired = min(profile.maxStudyBlockMinutes, 45)

        desired = max(25, desired)

        subject_candidates.append({
            "title": f"Revise {subject.subjectName}",
            "subject_name": subject.subjectName,
            "subtitle": f"Revision block • {subject.difficultyLevel} difficulty",
            "reason": "Ranked using exam closeness, confidence, difficulty, estimated load, and PYQ weight.",
            "score": score,
            "desired_minutes": desired,
            "type": "study",
            "source": "revision",
        })

    subject_candidates.sort(key=lambda x: x["score"], reverse=True)

    extra_candidates = []
    for item in subject_candidates[:3]:
        extra_candidates.append({
            "title": f"Practice more: {item['subject_name']}",
            "subject_name": item["subject_name"],
            "subtitle": "Extra focused revision",
            "reason": "Added because this subject remains one of the highest-risk areas.",
            "score": item["score"] - 5,
            "desired_minutes": 45 if item["desired_minutes"] >= 60 else item["desired_minutes"],
            "type": "study",
            "source": "revision",
        })

    candidates.extend(subject_candidates)
    candidates.extend(extra_candidates)
    candidates.sort(key=lambda x: x["score"], reverse=True)

    return candidates


def allocate_plan(
    profile: ProfileIn,
    free_windows: List[Dict[str, int]],
    candidates: List[Dict[str, Any]],
) -> Dict[str, Any]:
    total_goal_minutes = profile.preferredStudyHours * 60
    remaining_goal = total_goal_minutes
    items: List[Dict[str, Any]] = []

    total_study_minutes = 0
    total_break_minutes = 0
    candidate_index = 0

    for window in free_windows:
        if remaining_goal <= 0 or candidate_index >= len(candidates):
            break

        cursor = window["start"]

        while cursor < window["end"] and remaining_goal > 0 and candidate_index < len(candidates):
            candidate = candidates[candidate_index]

            block_minutes = max(25, min(candidate["desired_minutes"], profile.maxStudyBlockMinutes))
            block_minutes = min(block_minutes, remaining_goal)
            available_in_window = window["end"] - cursor

            if available_in_window < 25:
                break

            block_minutes = min(block_minutes, available_in_window)

            if block_minutes < 25:
                break

            block_start = cursor
            block_end = cursor + block_minutes

            items.append({
                "time_label": f"{format_minutes(block_start)} - {format_minutes(block_end)}",
                "title": candidate["title"],
                "subject_name": candidate["subject_name"],
                "subtitle": candidate["subtitle"],
                "reason": candidate["reason"],
                "score": candidate["score"],
                "type": "study",
                "source": candidate["source"],
            })

            total_study_minutes += block_minutes
            remaining_goal -= block_minutes
            cursor = block_end
            candidate_index += 1

            can_add_break = (
                candidate_index < len(candidates)
                and remaining_goal > 0
                and (window["end"] - cursor) >= (profile.preferredBreakMinutes + 25)
            )

            if can_add_break:
                break_start = cursor
                break_end = cursor + profile.preferredBreakMinutes

                items.append({
                    "time_label": f"{format_minutes(break_start)} - {format_minutes(break_end)}",
                    "title": "Break",
                    "subject_name": "Recovery",
                    "subtitle": f"{profile.preferredBreakMinutes} minute recovery break",
                    "reason": "Inserted automatically between study blocks.",
                    "score": 0,
                    "type": "break",
                    "source": "system",
                })

                total_break_minutes += profile.preferredBreakMinutes
                cursor = break_end

    return {
        "items": items,
        "total_study_minutes": total_study_minutes,
        "total_break_minutes": total_break_minutes,
    }


def build_summary(
    target_date: datetime,
    free_windows: List[Dict[str, int]],
    blocked_windows: List[Dict[str, int]],
    total_study_minutes: int,
    total_break_minutes: int,
    preferred_study_hours: int,
    items: List[Dict[str, Any]],
) -> str:
    date_label = target_date.strftime("%d/%m/%Y")

    if not free_windows:
        return f"No free study windows were found for {date_label}. Your day appears fully blocked."

    study_blocks = len([item for item in items if item["type"] == "study"])
    planned_hours = round(total_study_minutes / 60, 1)

    return (
        f"For {date_label}, the optimizer found {len(free_windows)} free window(s) "
        f"after removing {len(blocked_windows)} blocked slot(s). "
        f"It scheduled {study_blocks} study block(s), covering about {planned_hours} hour(s) "
        f"of study with {total_break_minutes} break minute(s). "
        f"Your daily target was {preferred_study_hours} hour(s)."
    )


# -----------------------------
# Endpoints
# -----------------------------
@app.get("/health")
def health():
    return {"status": "ok", "service": "smart-study-planner-ai"}


@app.post("/generate-study-plan")
def generate_study_plan(payload: GeneratePlanRequest):
    target_date = parse_date(payload.forDate) or datetime.now()

    wake_minute = parse_time_to_minutes(payload.profile.wakeTime)
    sleep_minute = parse_time_to_minutes(payload.profile.sleepTime)

    if sleep_minute <= wake_minute:
        sleep_minute += 24 * 60

    blocked_windows = build_blocked_windows(
        blocked_slots=payload.blockedSlots,
        target_date=target_date,
        wake_minute=wake_minute,
        sleep_minute=sleep_minute,
    )

    free_windows = build_free_windows(
        wake_minute=wake_minute,
        sleep_minute=sleep_minute,
        blocked_windows=blocked_windows,
    )

    candidates = build_candidates(
        profile=payload.profile,
        subjects=payload.subjects,
        tasks=payload.tasks,
        pyq_topics=payload.pyqTopics,
        today=target_date,
    )

    plan = allocate_plan(
        profile=payload.profile,
        free_windows=free_windows,
        candidates=candidates,
    )

    summary = build_summary(
        target_date=target_date,
        free_windows=free_windows,
        blocked_windows=blocked_windows,
        total_study_minutes=plan["total_study_minutes"],
        total_break_minutes=plan["total_break_minutes"],
        preferred_study_hours=payload.profile.preferredStudyHours,
        items=plan["items"],
    )

    return {
        "summary": summary,
        "wake_time": payload.profile.wakeTime,
        "sleep_time": payload.profile.sleepTime,
        "free_window_count": len(free_windows),
        "blocked_count_today": len(blocked_windows),
        "total_study_minutes": plan["total_study_minutes"],
        "total_break_minutes": plan["total_break_minutes"],
        "items": plan["items"],
    }


@app.post("/analyze-workload")
def analyze_workload(payload: GeneratePlanRequest):
    target_date = parse_date(payload.forDate) or datetime.now()

    wake_minute = parse_time_to_minutes(payload.profile.wakeTime)
    sleep_minute = parse_time_to_minutes(payload.profile.sleepTime)

    if sleep_minute <= wake_minute:
        sleep_minute += 24 * 60

    blocked_windows = build_blocked_windows(
        blocked_slots=payload.blockedSlots,
        target_date=target_date,
        wake_minute=wake_minute,
        sleep_minute=sleep_minute,
    )

    free_windows = build_free_windows(
        wake_minute=wake_minute,
        sleep_minute=sleep_minute,
        blocked_windows=blocked_windows,
    )

    free_minutes_today = sum(window["end"] - window["start"] for window in free_windows)
    blocked_minutes_today = sum(window["end"] - window["start"] for window in blocked_windows)

    pending_tasks = len([task for task in payload.tasks if normalize_status(task) != "completed"])

    upcoming_exams = 0
    low_confidence = 0

    for subject in payload.subjects:
        if subject.confidenceLevel.strip().lower() == "low":
            low_confidence += 1

        exam = parse_date(subject.examDate)
        if exam:
            days = (exam.date() - target_date.date()).days
            if 0 <= days <= 10:
                upcoming_exams += 1

    score = 0
    score += pending_tasks * 10
    score += upcoming_exams * 15
    score += low_confidence * 12

    if free_minutes_today < payload.profile.preferredStudyHours * 60:
        score += 20

    if blocked_minutes_today >= 180:
        score += 10

    score = min(score, 100)

    if score >= 70:
        level = "High"
        headline = "High workload pressure"
        subtitle = "Your day has limited free time compared to your current study demand."
    elif score >= 40:
        level = "Moderate"
        headline = "Moderate workload pressure"
        subtitle = "Your schedule is manageable, but some subjects and tasks still need careful ordering."
    else:
        level = "Low"
        headline = "Low workload pressure"
        subtitle = "Your current workload looks manageable for today."

    recommendations = []
    if free_minutes_today < payload.profile.preferredStudyHours * 60:
        recommendations.append("Your available time is lower than your preferred study goal today.")
    if blocked_minutes_today >= 180:
        recommendations.append("Large blocked periods reduce your flexible study windows.")
    if low_confidence > 0:
        recommendations.append("Prioritize low-confidence subjects earlier in the day.")
    if pending_tasks > 0:
        recommendations.append("Complete urgent pending tasks before extra revision blocks.")
    if not recommendations:
        recommendations.append("Current workload looks balanced. Maintain consistency.")

    return {
        "score": score,
        "level": level,
        "headline": headline,
        "subtitle": subtitle,
        "pending_task_count": pending_tasks,
        "upcoming_exam_count": upcoming_exams,
        "low_confidence_count": low_confidence,
        "free_minutes_today": free_minutes_today,
        "blocked_minutes_today": blocked_minutes_today,
        "recommendations": recommendations,
    }


@app.post("/recommend-breaks")
def recommend_breaks(payload: GeneratePlanRequest):
    max_block = payload.profile.maxStudyBlockMinutes
    break_minutes = payload.profile.preferredBreakMinutes

    recommendations = [
        f"Use study blocks of about {max_block} minutes at most.",
        f"Take recovery breaks of about {break_minutes} minutes between major blocks.",
        "Place tougher subjects earlier in larger free windows.",
        "Do not start a long study block right before a blocked class or event.",
    ]

    if max_block >= 90:
        recommendations.append("For long heavy sessions, include water or stretch breaks midway if needed.")

    return {
        "max_study_block_minutes": max_block,
        "preferred_break_minutes": break_minutes,
        "recommendations": recommendations,
    }