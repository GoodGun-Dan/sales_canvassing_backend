#!/usr/bin/env python3
"""
Script to generate PowerPoint presentation for thesis defense
Mobile Sales Canvassing Application
"""

from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE

def create_presentation():
    """Create PowerPoint presentation for thesis defense"""
    
    # Create new presentation
    prs = Presentation()
    prs.slide_width = Inches(10)
    prs.slide_height = Inches(7.5)
    
    # Color scheme
    primary_color = RGBColor(0, 51, 102)  # Dark blue
    secondary_color = RGBColor(0, 102, 204)  # Medium blue
    accent_color = RGBColor(255, 153, 0)  # Orange
    text_color = RGBColor(51, 51, 51)  # Dark gray
    
    # Function to add slide with layout
    def add_slide(title, content_points, subtitle=""):
        slide_layout = prs.slide_layouts[1]  # Title and Content
        slide = prs.slides.add_slide(slide_layout)
        
        # Title
        title_shape = slide.shapes.title
        title_shape.text = title
        title_para = title_shape.text_frame.paragraphs[0]
        title_para.font.size = Pt(36)
        title_para.font.bold = True
        title_para.font.color.rgb = primary_color
        
        # Content
        if content_points:
            content_shape = slide.placeholders[1]
            text_frame = content_shape.text_frame
            text_frame.clear()
            
            for i, point in enumerate(content_points):
                if i == 0:
                    p = text_frame.paragraphs[0]
                else:
                    p = text_frame.add_paragraph()
                p.text = point
                p.font.size = Pt(20)
                p.font.color.rgb = text_color
                p.level = 0
                p.space_after = Pt(12)
        
        return slide
    
    # Function to add slide with two columns
    def add_two_column_slide(title, left_content, right_content):
        slide_layout = prs.slide_layouts[5]  # Blank
        slide = prs.slides.add_slide(slide_layout)
        
        # Title
        left = Inches(0.5)
        top = Inches(0.3)
        width = Inches(9)
        height = Inches(1)
        title_box = slide.shapes.add_textbox(left, top, width, height)
        title_frame = title_box.text_frame
        title_frame.text = title
        title_para = title_frame.paragraphs[0]
        title_para.font.size = Pt(36)
        title_para.font.bold = True
        title_para.font.color.rgb = primary_color
        
        # Left column
        left_box = slide.shapes.add_textbox(left, Inches(1.5), Inches(4.2), Inches(5.5))
        left_frame = left_box.text_frame
        left_frame.word_wrap = True
        
        for i, item in enumerate(left_content):
            if i == 0:
                p = left_frame.paragraphs[0]
            else:
                p = left_frame.add_paragraph()
            p.text = item
            p.font.size = Pt(18)
            p.font.color.rgb = text_color
            p.space_after = Pt(10)
        
        # Right column
        right_box = slide.shapes.add_textbox(Inches(5.3), Inches(1.5), Inches(4.2), Inches(5.5))
        right_frame = right_box.text_frame
        right_frame.word_wrap = True
        
        for i, item in enumerate(right_content):
            if i == 0:
                p = right_frame.paragraphs[0]
            else:
                p = right_frame.add_paragraph()
            p.text = item
            p.font.size = Pt(18)
            p.font.color.rgb = text_color
            p.space_after = Pt(10)
        
        return slide
    
    # Function to add cover slide
    def add_cover_slide():
        slide_layout = prs.slide_layouts[6]  # Blank
        slide = prs.slides.add_slide(slide_layout)
        
        # Background rectangle
        background = slide.shapes.add_shape(
            MSO_SHAPE.RECTANGLE, Inches(0), Inches(0), Inches(10), Inches(7.5)
        )
        background.fill.solid()
        background.fill.fore_color.rgb = primary_color
        background.line.fill.background()
        
        # Title
        left = Inches(1)
        top = Inches(2.5)
        width = Inches(8)
        height = Inches(1.5)
        title_box = slide.shapes.add_textbox(left, top, width, height)
        title_frame = title_box.text_frame
        title_frame.text = "Mobile Sales Canvassing Application"
        title_para = title_frame.paragraphs[0]
        title_para.font.size = Pt(44)
        title_para.font.bold = True
        title_para.font.color.rgb = RGBColor(255, 255, 255)
        title_para.alignment = PP_ALIGN.CENTER
        
        # Subtitle
        subtitle_box = slide.shapes.add_textbox(left, Inches(4.2), width, Inches(1))
        subtitle_frame = subtitle_box.text_frame
        subtitle_frame.text = "Thesis Defense - Computing Capstone Project"
        subtitle_para = subtitle_frame.paragraphs[0]
        subtitle_para.font.size = Pt(24)
        subtitle_para.font.color.rgb = RGBColor(200, 200, 200)
        subtitle_para.alignment = PP_ALIGN.CENTER
        
        # Author
        author_box = slide.shapes.add_textbox(left, Inches(5.5), width, Inches(1))
        author_frame = author_box.text_frame
        author_frame.text = "Joseph Nugraha Wibawa"
        author_para = author_frame.paragraphs[0]
        author_para.font.size = Pt(20)
        author_para.font.color.rgb = RGBColor(255, 255, 255)
        author_para.alignment = PP_ALIGN.CENTER
        
        return slide
    
    # SLIDE 1: Cover
    add_cover_slide()
    
    # SLIDE 2: Background
    add_slide(
        "Background",
        [
            "Challenges in traditional sales canvassing systems:",
            "• Difficulty tracking sales representatives' locations in real-time",
            "• Unstructured and suboptimal outlet visit planning",
            "• Poor integration of sales and visit data",
            "• Ineffective and non-transparent sales team management",
            "• Lack of sales representative performance analytics",
            "",
            "Solution: Mobile Sales Canvassing Application with GPS tracking, outlet visit management, and real-time performance analytics"
        ]
    )
    
    # SLIDE 3: Problem Statement
    add_slide(
        "Problem Statement",
        [
            "How to design an effective sales canvassing system with GPS tracking?",
            "How to implement structured outlet visit management?",
            "How to integrate sales and visit data in real-time?",
            "How to provide comprehensive sales representative performance analytics dashboard?",
            "How to ensure data security and user access control?"
        ]
    )
    
    # SLIDE 4: Research Objectives
    add_slide(
        "Research Objectives",
        [
            "Develop a comprehensive Mobile Sales Canvassing Application with:",
            "• GPS tracking for monitoring sales representative locations",
            "• Structured outlet visit planning and management",
            "• Real-time integration of sales and visit data",
            "• Sales representative performance analytics dashboard",
            "• Secure authentication and authorization system",
            "• Excel upload/download for bulk data management"
        ]
    )
    
    # SLIDE 5: Methodology
    add_two_column_slide(
        "Development Methodology",
        [
            "1. Requirements Analysis",
            "   - Literature review",
            "   - Existing system analysis",
            "   - User needs identification",
            "",
            "2. System Design",
            "   - System architecture",
            "   - Database schema design",
            "   - UI/UX design",
            "",
            "3. Implementation",
            "   - Backend: Node.js/Express",
            "   - Frontend: Flutter",
            "   - Database: PostgreSQL"
        ],
        [
            "4. Testing",
            "   - Unit testing",
            "   - Integration testing",
            "   - User acceptance testing",
            "",
            "5. Deployment",
            "   - Server setup",
            "   - Mobile app deployment",
            "   - Monitoring & maintenance",
            "",
            "6. Evaluation",
            "   - Performance testing",
            "   - User feedback",
            "   - Documentation"
        ]
    )
    
    # SLIDE 6: System Architecture
    add_two_column_slide(
        "System Architecture",
        [
            "Backend Technologies:",
            "• Node.js with Express.js",
            "• PostgreSQL database",
            "• JWT authentication",
            "• RESTful API",
            "• Security: Helmet, Rate Limiting",
            "• File upload: Multer",
            "• Excel processing: XLSX",
            "",
            "Frontend Technologies:",
            "• Flutter framework",
            "• Dart programming language",
            "• OpenStreetMap integration",
            "• GPS & Geolocation",
            "• HTTP communication",
            "• Local storage",
            "• Chart visualization"
        ],
        [
            "Key Features:",
            "• Multi-role authentication",
            "  (Admin, Manager, Supervisor, Rep)",
            "• Real-time location tracking",
            "• Visit planning & management",
            "• Sales order processing",
            "• Payment tracking",
            "• Analytics dashboard",
            "• Excel import/export",
            "• Team management",
            "",
            "Security Features:",
            "• Password hashing (bcrypt)",
            "• JWT token authentication",
            "• Role-based access control",
            "• Rate limiting",
            "• CORS configuration"
        ]
    )
    
    # SLIDE 7: Database Schema
    add_slide(
        "Database Schema - Core Tables",
        [
            "Core Tables:",
            "• employee - Employee/sales representative data",
            "• user_account - Authentication and authorization",
            "• outlet - Outlet/store data to be visited",
            "• team & team_member - Sales team management",
            "",
            "Operational Tables:",
            "• visit - Outlet visit data",
            "• sales_order - Sales order data",
            "• order_detail - Order item details",
            "• product - Product catalog",
            "• payment - Payment data",
            "",
            "Supporting Tables:",
            "• outlet_assignment - Outlet assignment to sales reps",
            "• outlet_rep_balance - Outlet visit balance"
        ]
    )
    
    # SLIDE 8: Sales Representative Features
    add_slide(
        "Sales Representative Features",
        [
            "Personal Dashboard:",
            "• View today's visit schedule",
            "• Check-in/check-out visits",
            "• Input sales orders",
            "• Track daily sales performance",
            "",
            "Location Features:",
            "• Real-time GPS tracking",
            "• Navigation to outlets",
            "• Location-based check-in",
            "• Distance calculation",
            "",
            "Data Management:",
            "• Product order input",
            "• Excel upload/download",
            "• View visit history"
        ]
    )
    
    # SLIDE 9: Admin/Manager Features
    add_slide(
        "Admin/Manager Features",
        [
            "Team Management:",
            "• Add/Edit/Delete sales representatives",
            "• Assign outlets to sales reps",
            "• Monitor team performance",
            "• View team live locations",
            "",
            "Analytics Dashboard:",
            "• Sales analytics per sales rep",
            "• Visit performance metrics",
            "• Top products & outlets",
            "• Daily/weekly/monthly reports",
            "",
            "Data Management:",
            "• Import outlet data via Excel",
            "• Manage product catalog",
            "• View all orders & payments"
        ]
    )
    
    # SLIDE 10: Backend Implementation
    add_two_column_slide(
        "Backend API Implementation",
        [
            "Authentication Endpoints:",
            "• POST /api/auth/login",
            "• GET /api/auth/profile",
            "• PUT /api/auth/profile",
            "• POST /api/auth/change-password",
            "",
            "Sales Rep Management:",
            "• GET /api/admin/sales-reps",
            "• POST /api/admin/sales-reps",
            "• PUT /api/admin/sales-reps/:id",
            "• DELETE /api/admin/sales-reps/:id",
            "",
            "Visit Management:",
            "• GET /api/visits",
            "• POST /api/visits",
            "• PUT /api/visits/:id/check-in",
            "• PUT /api/visits/:id/check-out"
        ],
        [
            "Sales Order Endpoints:",
            "• GET /api/orders",
            "• POST /api/orders",
            "• GET /api/orders/:id",
            "",
            "Analytics Endpoints:",
            "• GET /api/analytics/sales",
            "• GET /api/analytics/visits",
            "• GET /api/admin/sales-reps/:id/analytics",
            "",
            "File Operations:",
            "• POST /api/import/outlets",
            "• GET /api/export/orders",
            "",
            "Location Services:",
            "• PUT /api/location/update",
            "• GET /api/admin/sales-reps/:id/location"
        ]
    )
    
    # SLIDE 11: Frontend Implementation
    add_slide(
        "Frontend Flutter Implementation",
        [
            "Main Screens:",
            "• Login Screen - User authentication",
            "• Dashboard Screen - Visit & sales overview",
            "• Visit List Screen - List of outlets to visit",
            "• Visit Detail Screen - Visit details & check-in/out",
            "• Order Form Screen - Sales order input",
            "• Map Screen - Outlet location map & navigation",
            "",
            "State Management:",
            "• Provider pattern for state management",
            "• Shared preferences for local storage",
            "• HTTP client for API communication",
            "",
            "UI Components:",
            "• Material Design components",
            "• Custom widgets for charts & maps",
            "• Responsive design for various screen sizes"
        ]
    )
    
    # SLIDE 12: Results and Discussion
    add_two_column_slide(
        "Results and Discussion",
        [
            "Functional Testing:",
            "✓ Authentication works correctly",
            "✓ Multi-role access control successful",
            "✓ GPS tracking accurate",
            "✓ Visit management runs smoothly",
            "✓ Sales order processing successful",
            "✓ Excel import/export functional",
            "",
            "Performance Testing:",
            "✓ Response time < 2 seconds",
            "✓ Real-time GPS updates",
            "✓ Smooth data synchronization",
            "✓ Optimal memory usage"
        ],
        [
            "Security Testing:",
            "✓ Password hashing implemented",
            "✓ Secure JWT authentication",
            "✓ Rate limiting prevents brute force",
            "✓ Proper CORS configuration",
            "",
            "User Acceptance Testing:",
            "✓ Intuitive and user-friendly UI",
            "✓ Features meet user needs",
            "✓ Offline capability available",
            "✓ Satisfying performance"
        ]
    )
    
    # SLIDE 13: Conclusion
    add_slide(
        "Conclusion",
        [
            "Mobile Sales Canvassing Application successfully developed with comprehensive features:",
            "• GPS tracking for real-time sales representative location monitoring",
            "• Structured and efficient outlet visit management",
            "• Seamless integration of sales and visit data",
            "• Comprehensive performance analytics dashboard",
            "• Robust security system with multi-role access control",
            "",
            "The application provides an effective solution to traditional sales canvassing problems",
            "and improves sales team efficiency and productivity"
        ]
    )
    
    # SLIDE 14: Future Work
    add_slide(
        "Future Development Suggestions",
        [
            "Additional features that can be developed:",
            "• Push notifications for visit reminders",
            "• Integration with payment gateway",
            "• AI-powered route optimization",
            "• Voice command for data input",
            "• Offline-first architecture for better offline experience",
            "• Integration with existing CRM systems",
            "• Advanced analytics with machine learning",
            "• Multi-language support",
            "• Web dashboard for desktop admin access"
        ]
    )
    
    # SLIDE 15: Thank You
    slide_layout = prs.slide_layouts[6]  # Blank
    slide = prs.slides.add_slide(slide_layout)
    
    # Background rectangle
    background = slide.shapes.add_shape(
        MSO_SHAPE.RECTANGLE, Inches(0), Inches(0), Inches(10), Inches(7.5)
    )
    background.fill.solid()
    background.fill.fore_color.rgb = primary_color
    background.line.fill.background()
    
    # Thank you text
    left = Inches(1)
    top = Inches(3)
    width = Inches(8)
    height = Inches(1.5)
    thank_box = slide.shapes.add_textbox(left, top, width, height)
    thank_frame = thank_box.text_frame
    thank_frame.text = "Thank You"
    thank_para = thank_frame.paragraphs[0]
    thank_para.font.size = Pt(48)
    thank_para.font.bold = True
    thank_para.font.color.rgb = RGBColor(255, 255, 255)
    thank_para.alignment = PP_ALIGN.CENTER
    
    # Subtitle
    subtitle_box = slide.shapes.add_textbox(left, Inches(4.5), width, Inches(1))
    subtitle_frame = subtitle_box.text_frame
    subtitle_frame.text = "Questions & Discussion"
    subtitle_para = subtitle_frame.paragraphs[0]
    subtitle_para.font.size = Pt(24)
    subtitle_para.font.color.rgb = RGBColor(200, 200, 200)
    subtitle_para.alignment = PP_ALIGN.CENTER
    
    return prs

if __name__ == "__main__":
    print("Creating PowerPoint presentation...")
    prs = create_presentation()
    
    # Save presentation
    output_file = "c:\\Users\\Roby\\Project\\sales_canvassing\\Sales_Canvassing_Presentation.pptx"
    prs.save(output_file)
    
    print(f"Presentation created successfully: {output_file}")
    print(f"Total slides: {len(prs.slides)}")
