#version 330

// Input from vertex shader
in vec3 fragPosition;

// Uniforms  
uniform sampler2D texture0;
uniform float rotationY;    // Y-axis rotation in radians
uniform float exposure;     // EV adjustment
uniform float intensity;    // Brightness multiplier

// Output
out vec4 finalColor;

// Convert 3D direction to equirectangular UV coordinates
vec2 SampleSphericalMap(vec3 v)
{
    // Apply Y-axis rotation
    float cosY = cos(rotationY);
    float sinY = sin(rotationY);
    vec3 rotated = vec3(
        v.x * cosY - v.z * sinY,
        v.y,
        v.x * sinY + v.z * cosY
    );
    
    // Convert to spherical coordinates
    vec2 uv = vec2(atan(rotated.z, rotated.x), asin(rotated.y));
    
    // Normalize to [0,1] range
    uv *= vec2(0.1591, 0.3183); // 1/(2*PI), 1/PI
    uv += 0.5;
    
    return uv;
}

void main()
{
    // Get direction vector from fragment position
    vec3 envDirection = normalize(fragPosition);
    
    // Sample equirectangular map
    vec2 uv = SampleSphericalMap(envDirection);
    vec3 color = texture(texture0, uv).rgb;
    
    // Apply exposure and intensity
    color *= pow(2.0, exposure) * intensity;
    
    // Tone mapping (simple Reinhard)
    color = color / (color + vec3(1.0));
    
    // Gamma correction
    color = pow(color, vec3(1.0/2.2));
    
    finalColor = vec4(color, 1.0);
}