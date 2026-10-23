"""Generate FuelSmart LK's small, deterministic on-device demand regressor.

The generated model is bundled with the iOS app. Runtime station data never
leaves the device for inference.
"""

from pathlib import Path

import coremltools as ct
from coremltools.proto import FeatureTypes_pb2, Model_pb2


MODEL_PATH = Path(__file__).resolve().parents[1] / "FuelLanka" / "FuelDemandRegressor.mlmodel"

spec = Model_pb2.Model()
spec.specificationVersion = 1
spec.description.metadata.shortDescription = "Estimates next-day station fuel demand locally."
spec.description.metadata.author = "FuelSmart LK"
spec.description.metadata.versionString = "1.0"

inputs = (
    ("recent3Average", "Average confirmed daily litres over the latest three days."),
    ("recent7Average", "Average confirmed daily litres over the latest seven days."),
    ("previous7Average", "Average confirmed daily litres over the preceding seven days."),
    ("recentTrend", "Difference between recent and preceding daily demand."),
    ("isWeekend", "One for Saturday or Sunday, otherwise zero."),
)

for name, description in inputs:
    feature = spec.description.input.add()
    feature.name = name
    feature.shortDescription = description
    feature.type.doubleType.MergeFrom(FeatureTypes_pb2.DoubleFeatureType())

output = spec.description.output.add()
output.name = "predictedDailyLitres"
output.shortDescription = "Estimated litres of demand for the next day."
output.type.doubleType.MergeFrom(FeatureTypes_pb2.DoubleFeatureType())
spec.description.predictedFeatureName = output.name

# A deliberately small transparent regression. Recent activity receives the
# greatest weight; the trend and weekend terms adjust the next-day estimate.
spec.glmRegressor.offset.append(0.0)
weights = spec.glmRegressor.weights.add()
weights.value.extend([0.55, 0.30, 0.15, 0.10, -75.0])

ct.utils.save_spec(spec, str(MODEL_PATH))
print(f"Generated {MODEL_PATH}")
