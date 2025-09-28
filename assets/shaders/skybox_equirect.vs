#version 330

// Input vertex attributes
in vec3 vertexPosition;

// Output to fragment shader
out vec3 fragPosition;

// Uniform matrices
uniform mat4 mvp;

void main()
{
    // Pass position to fragment shader for direction calculation
    fragPosition = vertexPosition;
    
    // Position vertex, but remove translation to keep skybox centered on camera
    gl_Position = mvp * vec4(vertexPosition, 1.0);
    
    // Force skybox to always be at far plane
    gl_Position.z = gl_Position.w;
}