package com.grirp.incidentmanagement.controller;


import com.grirp.incidentmanagement.DTO.IncidentDto;
import com.grirp.incidentmanagement.DTO.IncidentResponseDto;
import com.grirp.incidentmanagement.service.IncidentService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.validation.Valid;
import java.util.List;

@RestController
@RequestMapping("/incidents")
public class IncidentController {

    @Autowired
    private IncidentService service;

    @PostMapping
    public ResponseEntity<IncidentResponseDto> createIncident(@Valid @RequestBody IncidentDto incidentDto) {
        IncidentResponseDto response = service.createIncident(incidentDto);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @PutMapping("/{id}")
    public ResponseEntity<IncidentResponseDto> updateIncident(@PathVariable("id") Long id, @Valid @RequestBody IncidentDto incidentDto) {
        IncidentResponseDto response = service.updateIncident(id, incidentDto);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/{id}")
    public ResponseEntity<IncidentResponseDto> getIncident(@PathVariable("id") Long id) {
        IncidentResponseDto response = service.getIncident(id);
        return ResponseEntity.ok(response);
    }

    @GetMapping
    public ResponseEntity<List<IncidentResponseDto>> getAllIncidents() {
        List<IncidentResponseDto> responses = service.getAllIncidents();
        return ResponseEntity.ok(responses);
    }
}