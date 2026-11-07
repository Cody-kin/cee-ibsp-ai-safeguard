class AlertLogic:
    def __init__(self):
        self.danger_classes = ['fall', 'fire', 'smoke']

    def process_frame_detections(self, detections, cam_status):
        alerts = []
        if cam_status != "OK": return alerts
        for det in detections:
            obj_class = det['class'].lower()
            if obj_class in self.danger_classes:
                alerts.append({'type': obj_class, 'conf': det['conf']})
        return alerts
