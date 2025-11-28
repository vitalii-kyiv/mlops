# Comparison of Fat vs Slim Images

| Image tag | Base image | Size\* | Layers | Extra tooling | Notes |
|-----------|------------|--------|--------|---------------|-------|
| `lesson-3-fat` | `python:3.10-slim` | ~1.88 GB | 13 | Build-essential, git, pip-installed deps у фінальному шарі | Одинарний етап: системні пакети + PyTorch CPU встановлюються безпосередньо у runtime, тому шар важить майже 2 GB. |
| `lesson-3-slim` | `python:3.9-slim` (runtime) | ~1.37 GB | 10 | Тільки runtime + wheel-и з білдера | Multi-stage: залежності ставляться у `/opt/deps` на builder, у фінал копіюється лише модель та бібліотеки. |

\*Measured with `docker images lesson-3-fat`/`lesson-3-slim` after running the commands from `README.md`. Actual numbers may vary slightly depending on host platform and torch wheel variant (CPU/GPU).

## Observations

- Slim зменшив розмір приблизно на 27 % за рахунок винесення залежностей у builder і відсутності `apt` у рантаймі.
- Fat бере всі залежності напряму в одному шарі, тому підсумок визначається вагою wheel-артефактів PyTorch (~600 MB) і базового образу.
- Обидва образи використовують CPU-only PyTorch 2.2.1 + NumPy 1.26, тому inference консистентний.
- У slim файли `export_model.py` та build-утиліти не потрапляють у рантайм, що зменшує attack surface.

## Opportunities for Further Optimization

1. Перенести runtime на distroless або `python:3.9-alpine` (за умови сумісності з wheel) для зменшення ще ~150–200 MB.
2. Квантувати TorchScript модель (INT8) або перейти на компактнішу архітектуру (EfficientNet-Lite) для зменшення шару з артефактами.
3. Видаляти `torchvision` з runtime, якщо вона потрібна лише під час експорту, і постачати лише попередньо обчислені transforms/labels.
4. Використовувати `pip install --require-hashes` + `pip cache purge` на builder, щоб уникнути зайвих артефактів і посилити безпеку.
5. Додати `HEALTHCHECK` та скрипти самотестування в контейнер, щоб автоматично виявляти зламані збірки без ручного запуску CLI.

