# Thai time rules

How Krasip writes a Thai time that was spoken. Agreed with the founders on 2026-10-14. The text policy, the correction model's training data, and `CORRECTION_STYLE_RULES.md` all follow this file.

## Why

People type times in chat the way they say them: `6 โมงเย็น`, `บ่าย 2`, `เที่ยง`. The 24-hour clock (`18:00`) is for schedules and meetings. Krasip writes whole hours the casual way and switches to the clock only when the clock is the clearer way to write it.

## Ground rules

| Rule | Decision |
| --- | --- |
| Setting | None. Every user gets the same style. |
| Whole hour | Keep the spoken words, write the number as a digit: `6 โมงเย็น` |
| Hour with minutes | 24-hour clock with a leading zero: `14:30`, `07:15` |
| Hour said the 24-hour way | 24-hour clock: `14:00` |
| Unclear hour | Keep the spoken words. Never guess. |
| Time said in English | Unchanged: `7 o'clock`, `9:30 AM` |

The clock is always the true 24-hour time. `ห้าโมงครึ่ง` is `17:30`, never `5:30`, because `5:30` means `ตีห้าครึ่ง`.

## Whole hours

| Spoken | Written |
| --- | --- |
| ตีหนึ่ง … ตีห้า | ตี 1 … ตี 5 |
| หกโมงเช้า … สิบเอ็ดโมงเช้า | 6 โมงเช้า … 11 โมงเช้า |
| สองโมงเช้า … ห้าโมงเช้า (the old way of counting) | 2 โมงเช้า … 5 โมงเช้า |
| เจ็ดโมง … สิบเอ็ดโมง | 7 โมง … 11 โมง |
| หกโมง | 6 โมง |
| เที่ยง, เที่ยงตรง, บ่ายโมง | unchanged |
| บ่ายหนึ่ง … บ่ายสี่, บ่ายสองโมง | บ่าย 1 … บ่าย 4, บ่าย 2 โมง |
| สี่โมง, ห้าโมง | 4 โมง, 5 โมง |
| สี่โมงเย็น … หกโมงเย็น | 4 โมงเย็น … 6 โมงเย็น |
| หนึ่งทุ่ม … ห้าทุ่ม | 1 ทุ่ม … 5 ทุ่ม |
| ทุ่มนึง, เที่ยงคืน | unchanged |
| หกโมงตรง | 6 โมงตรง |
| `6 โมง เย็น`, a space written by the speech model | 6 โมงเย็น |

## Hours with minutes

| Spoken | Written |
| --- | --- |
| ตีสองครึ่ง, ตีห้าสิบห้า | 02:30, 05:15 |
| เจ็ดโมงสิบห้า | 07:15 |
| สองโมงเช้าครึ่ง (old way) | 08:30 |
| สี่โมงเช้าครึ่ง (old way) | 10:30 |
| สิบโมงครึ่ง | 10:30 |
| เที่ยงครึ่ง | 12:30 |
| บ่ายสองครึ่ง, บ่ายสองโมงสี่สิบ | 14:30, 14:40 |
| สี่โมงครึ่ง | 16:30 |
| ห้าโมงครึ่ง | 17:30 |
| หกโมงเย็นครึ่ง, หกโมงครึ่งตอนเย็น | 18:30 |
| ทุ่มครึ่ง, สองทุ่มครึ่ง | 19:30, 20:30 |
| เที่ยงคืนครึ่ง, หกทุ่มครึ่ง | 00:30 |

Minutes may be spoken as `ครึ่ง`, as a number (`สิบห้า`, `45`), or with `นาที`. A number followed by a counting word is not minutes: `สิบคน` stays as it is.

The period word is part of the time and is not repeated: `หกโมงครึ่งตอนเย็น` becomes `18:30`, not `18:30 ตอนเย็น`.

## Said the 24-hour way

| Spoken | Written |
| --- | --- |
| สิบสามโมง … ยี่สิบสามโมง | 13:00 … 23:00 |
| แปดนาฬิกา, สิบแปดนาฬิกา, สิบแปดนาฬิกาสามสิบนาที | 08:00, 18:00, 18:30 |

## The one unclear hour: หกโมง

`หกโมง` on its own can mean 06:00 or 18:00, and people say it for both. Every other hour is clear:

- `เจ็ดโมง` to `สิบเอ็ดโมง` are morning. 7 PM is `หนึ่งทุ่ม`.
- `สี่โมง` and `ห้าโมง` are afternoon. 4 AM is `ตีสี่`, and 10 AM is `สิบโมง` or `สี่โมงเช้า`.

As a whole hour, `หกโมง` becomes `6 โมง`, which is fine because the spoken style keeps it as unclear as it was said. With minutes, a clock would force a guess, so it stays spoken unless `เช้า` or `เย็น` sits just before it:

| Spoken | Written |
| --- | --- |
| หกโมงครึ่ง | 6 โมงครึ่ง |
| หกโมงสิบห้า | 6 โมง 15 |
| ตอนเช้าหกโมงครึ่ง | ตอนเช้า 06:30 |
| เย็นนี้เจอกันหกโมงครึ่ง | เย็นนี้เจอกัน 18:30 |
| ดื่มน้ำเย็นตอนหกโมงครึ่ง | ดื่มน้ำเย็นตอน 6 โมงครึ่ง |

"Just before" means at most a few letters in between, with no number and no other time of day. The word before stays, because it can carry more than the time of day (`เย็นนี้` also says today). `เย็น` meaning cold (`น้ำเย็น`, `อากาศเย็น`) does not count.

## Never a clock

| Spoken | Written | Why |
| --- | --- | --- |
| อีกสิบนาทีหกโมง | อีกสิบนาที 6 โมง | Counts back from the hour, so it means 5:50. Only the hour is touched, as a whole hour. |

## Left unchanged

| Spoken | Why |
| --- | --- |
| สองชั่วโมงครึ่ง, ครึ่งวัน | A length of time, not a clock time |
| เขาทุ่มหนึ่งล้านบาท, ทุ่มเท | `ทุ่ม` means spending or effort here |

A range is handled piece by piece: `สิบโมงถึงเที่ยง` becomes `10 โมงถึงเที่ยง`.
