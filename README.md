# Liquid Sensing Quick Start

This version uses one unified 15-second capture protocol for both tasks:

1. Liquid classification
2. Water height / volume estimation

## 1. Fixed capture protocol

Every sample must follow this timing:

```text
0-5 s    empty cup
5-10 s   replace the cup contents with the target liquid
10-15 s  keep the target liquid steady
```

The new analysis rule is:

- Classification: use the phase difference between one short segment from the first 5 seconds and one short segment from the last 5 seconds.
- Height estimation: use only amplitude features from the last 5 seconds.

## 2. Check hardware

```matlab
runPipeline
runPipeline('check')
```

## 3. Train liquid classification

Use the same fill height for all liquid types.

```matlab
runPipeline('collect-class')
runPipeline('classify')
```

To test a new unknown liquid:

```matlab
collectData('unknown', NaN)
runPipeline('predict-class')
```

## 4. Train water height estimation

Recommended levels:

```matlab
[0, 250, 500, 750, 1000]
```

Collect and train:

```matlab
runPipeline('collect-height')
runPipeline('train-height', 'water')
```

To predict an unknown water amount in the same beaker:

```matlab
collectData('water', NaN)
runPipeline('predict-height')
```

## 5. IQ analysis

```matlab
runPipeline('iq')
runPipeline('analyze-latest')
```

The IQ figure now directly compares:

- the empty-cup baseline segment
- the final liquid measurement segment
- their amplitude traces
- the centroid phase difference used for classification

## 6. Main simplifications

- One capture protocol for all tasks.
- No large high-dimensional feature set.
- No PCA and no segment voting for classification.
- Classification mainly uses phase difference.
- Height estimation only uses amplitude features.
