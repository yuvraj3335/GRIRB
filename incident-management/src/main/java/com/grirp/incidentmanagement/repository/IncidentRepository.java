package com.grirp.incidentmanagement.repository;

import com.grirp.incidentmanagement.model.Incident;
import org.springframework.data.jpa.repository.JpaRepository;

public interface IncidentRepository extends JpaRepository<Incident, Long> {
}
