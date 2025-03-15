package com.grirp.incidentmanagement.service;

import com.grirp.incidentmanagement.DTO.IncidentDto;
import com.grirp.incidentmanagement.DTO.IncidentResponseDto;
import com.grirp.incidentmanagement.Event.IncidentEvent;
import com.grirp.incidentmanagement.model.Incident;
import com.grirp.incidentmanagement.repository.IncidentRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class IncidentService {

    @Autowired
    private IncidentRepository repository;

    @Autowired
    private KafkaTemplate<String, IncidentEvent> kafkaTemplate;

    @Value("${kafka.topic.incidents}")
    private String incidentsTopic;

    public IncidentResponseDto createIncident(IncidentDto incidentDto) {
        Incident incident = new Incident();
        incident.setDescription(incidentDto.getDescription());
        incident.setStatus(incidentDto.getStatus());
        incident.setIncidentTypes(incidentDto.getIncidentTypes()); // ✅ Updated to List<String>

        Incident saved = repository.save(incident);

        // Publish event
        IncidentEvent event = new IncidentEvent(
                saved.getId(),
                "CREATED",
                saved.getIncidentTypes(),
                LocalDateTime.now()
        );
        kafkaTemplate.send(incidentsTopic, event);

        return mapToResponseDto(saved);
    }

    public IncidentResponseDto updateIncident(Long id, IncidentDto incidentDto) {
        Incident incident = repository.findById(id)
                .orElseThrow(() -> new RuntimeException("Incident not found"));
        incident.setDescription(incidentDto.getDescription());
        incident.setStatus(incidentDto.getStatus());
        incident.setIncidentTypes(incidentDto.getIncidentTypes()); // ✅ Updated to List<String>

        Incident updated = repository.save(incident);

        // Publish event
        IncidentEvent event = new IncidentEvent(
                updated.getId(),
                "UPDATED",
                updated.getIncidentTypes(),
                LocalDateTime.now()
        );
        kafkaTemplate.send(incidentsTopic, event);

        return mapToResponseDto(updated);
    }

    public IncidentResponseDto getIncident(Long id) {
        Incident incident = repository.findById(id)
                .orElseThrow(() -> new RuntimeException("Incident not found"));
        return mapToResponseDto(incident);
    }

    public List<IncidentResponseDto> getAllIncidents() {
        return repository.findAll().stream()
                .map(this::mapToResponseDto)
                .collect(Collectors.toList());
    }

    private IncidentResponseDto mapToResponseDto(Incident incident) {
        IncidentResponseDto dto = new IncidentResponseDto();
        dto.setId(incident.getId());
        dto.setDescription(incident.getDescription());
        dto.setStatus(incident.getStatus());
        dto.setIncidentTypes(incident.getIncidentTypes());
        dto.setCreatedAt(incident.getCreatedAt());
        dto.setUpdatedAt(incident.getUpdatedAt());
        return dto;
    }
}
