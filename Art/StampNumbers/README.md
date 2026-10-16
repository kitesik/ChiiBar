# Illustrated upgrade numbers

Production numeral PNGs for the daily upgrade stamp, created with the built-in image_gen tool on 2026-10-16. Each number from 0 through 30 has its own illustration; these are not font screenshots.

- `00.png` through `30.png`: original generated transparent images, unchanged.
- `07.png`: initial style reference. Other numbers were generated individually using this reference.
- `prompts.json`: exact reference prompt and the shared prompt template, substituting NUMBER with the requested integer.
- The renderer trims transparent margins only in memory, fits the illustration inside the stamp, and caches a maximum-192px display image. The saved PNGs remain intact.
- Counts above 30 use the illustrated 0–9 digits. The saved count, progression rules, and accessibility labels remain numeric and unchanged.
- Build packaging requires all 31 images; image accuracy and 1–30 layouts are visually reviewed in the number-stamps preview.

## 금빛 업그레이드 배지 (0.4.12)

`badge-gold.png`는 사용자가 제공한 금빛 다이아몬드·리본 배지를 참고해 내장 이미지 생성 도구로 새로 제작한 투명 배경 이미지입니다. 중앙 숫자는 기존 개별 숫자 이미지를 겹치고 리본의 ‘업그레이드’는 앱에서 표시합니다. 원본은 수정하지 않고 보관합니다. 제작 요청은 `badge-prompt.txt`에 기록했습니다.

## 손그림 파스텔 배지 (0.4.13)

`badge-pastel.png`는 사용자가 제공한 치이카와 그림의 선과 명도·배색을 참고해 내장 이미지 생성 도구로 제작한 배지입니다. 강한 금속 광택과 주황색을 크림색 테두리·하늘색 중심·민트색 뒷판과 갈색 선으로 바꿨습니다. 중앙 숫자와 리본 배치는 유지했습니다. 요청은 `badge-pastel-prompt.txt`에 기록했습니다.
