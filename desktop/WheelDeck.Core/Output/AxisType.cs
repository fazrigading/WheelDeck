namespace WheelDeck.Core.Output;

/// <summary>The analog axes the virtual output backend can drive.</summary>
public enum AxisType
{
    /// <summary>Steering wheel angle, normalized -1.0..1.0 where 0 is centered.</summary>
    Steering,

    /// <summary>Accelerator pedal pressure, 0.0..1.0.</summary>
    Accelerator,

    /// <summary>Brake pedal pressure, 0.0..1.0.</summary>
    Brake,

    /// <summary>Clutch pedal pressure, 0.0..1.0.</summary>
    Clutch
}
